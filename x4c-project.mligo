(* An FA2 contract for carbon tokens *)
(* FA2 Proposal TZIP: https://gitlab.com/tezos/tzip/-/blob/master/proposals/tzip-12/tzip-12.md *)
(* FA2 Standard: https://tezos.b9lab.com/fa2 *)


(* =============================================================================
 * Storage
 * ============================================================================= *)

type fa2_token_id = nat
type fa2_amt = nat
type fa2_owner = address
type fa2_operator = address
type token_metadata = [@layout:comb]{
    token_id : nat ; 
    token_info : (string, bytes) map ;
}
type contract_metadata = (string, bytes) big_map

type storage = {
    // address of the main carbon contract and project owner
    owner : address ; 
    carbon_contract : address ; 

    // the ledger keeps track of who owns what token
    ledger : (fa2_owner * fa2_token_id , fa2_amt) big_map ; 
    
    // an operator can trade tokens on behalf of the fa2_owner
    // if the key (owner, operator, token_id) returns some k : nat, this denotes that the operator has (one-time?) permissions to operate k tokens
    // if there is no entry, the operator has no permissions
    // such permissions need to granted, e.g. for the burn entrypoint in the carbon contract
    operators : (fa2_owner * fa2_operator * fa2_token_id, nat) big_map;
    
    // token metadata for each token type supported by this contract
    token_metadata : (fa2_token_id, token_metadata) big_map;
    // contract metadata 
    metadata : (string, bytes) big_map;
}

type result = (operation list) * storage


(* =============================================================================
 * Entrypoint Type Definition
 * ============================================================================= *)
type transfer_to = [@layout:comb]{ to_ : address ; token_id : nat ; amount : nat ; }
type transfer = 
    [@layout:comb]
    { from_ : address; 
      txs : transfer_to list; }

type requests = [@layout:comb]{ owner : address ; token_id : nat ; }
type request = [@layout:comb]{ owner : address ; token_id : nat ; }
type callback_data = [@layout:comb]{ request : request ; balance : nat ; }
type balance_of = [@layout:comb]{
    requests : requests list ; 
    callback : callback_data list contract ;
}

type operator_data = [@layout:comb]{ owner : address ; operator : address ; token_id : nat ; qty : nat ; }
type update_operator = 
    | Add_operator of operator_data
    | Remove_operator of operator_data
type update_operators = update_operator list

type mintburn_data = { owner : address ; token_id : nat ; qty : nat ; }
type mintburn = mintburn_data list

type get_metadata = {
    token_ids : nat list ;
    callback : token_metadata list contract ;
}

type entrypoint = 
| Transfer of transfer list // transfer tokens 
| Balance_of of balance_of // query an address's balance
| Update_operators of update_operators // change operators for some address
| Mint of mintburn // mint tokens
| Burn of mintburn // burn tokens 
| Get_metadata of get_metadata // query the metadata of a given token
| Add_zone of token_metadata list 
| Update_contract_metadata of contract_metadata


(* =============================================================================
 * Error codes
 * ============================================================================= *)

let error_FA2_TOKEN_UNDEFINED = 0n // One of the specified token_ids is not defined within the FA2 contract
let error_FA2_INSUFFICIENT_BALANCE = 1n // A token owner does not have sufficient balance to transfer tokens from owner's account
let error_FA2_TX_DENIED = 2n // A transfer failed because of fa2_operatortransfer_policy == No_transfer
let error_FA2_NOT_OWNER = 3n // A transfer failed because fa2_operatortransfer_policy == fa2_ownertransfer and it is invoked not by the token owner
let error_FA2_NOT_OPERATOR = 4n // A transfer failed because fa2_operatortransfer_policy == fa2_owneror_fa2_operatortransfer and it is invoked neither by the token owner nor a permitted operator
let error_FA2_OPERATORS_UNSUPPORTED = 5n // update_operators entrypoint is invoked and fa2_operatortransfer_policy is No_transfer or fa2_ownertransfer
let error_FA2_RECEIVER_HOOK_FAILED = 6n // The receiver hook failed. This error MUST be raised by the hook implementation
let error_FA2_SENDER_HOOK_FAILED = 7n // The sender failed. This error MUST be raised by the hook implementation
let error_FA2_RECEIVER_HOOK_UNDEFINED = 8n // Receiver hook is required by the permission behavior, but is not implemented by a receiver contract
let error_FA2_SENDER_HOOK_UNDEFINED = 9n // Sender hook is required by the permission behavior, but is not implemented by a sender contract
let error_PERMISSIONS_DENIED = 10n // General catch-all for operator-related permission errors
let error_ID_ALREADY_IN_USE = 11n // A token ID can only be used once, error if a user wants to add a token ID that's already there
let error_COLLISION = 12n

(* =============================================================================
 * Aux Functions
 * ============================================================================= *)

// an auxiliary function for querying an address's balance
let rec owner_and_id_to_balance (param : (callback_data list) * (requests list) * ((fa2_owner * fa2_token_id , fa2_amt) big_map)) : callback_data list =
    let (accumulator, request_list, ledger) = param in
    match request_list with
    | [] -> accumulator 
    | h :: t -> 
        let owner = h.owner in 
        let token_id = h.token_id in
        let qty =
            match Big_map.find_opt (owner, token_id) ledger with 
            | None -> 0n
            | Some owner_balance -> owner_balance in
        let request = { owner = owner ; token_id = token_id ; } in
        let accumulator = { request = request ; balance = qty ; } :: accumulator in
        owner_and_id_to_balance (accumulator, t, ledger) 


(* =============================================================================
 * Entrypoint Functions
 * ============================================================================= *)

// The transfer entrypoint function
// The input type is a tuple: (sender, list_of_transfers) where the first entry corresponds 
//    to the sender ("from"), and the second is a list with transfer data.
// This list of transfers has entries of the form (receiver, token_id, amount) = (address * nat * nat)
// The transfer function creates a list of transfer operations recursively
let rec transfer_txn (param , storage : transfer * storage) : storage = 
    match param.txs with
    | [] -> storage
    | hd :: tl ->
        let (from, to, token_id, qty) = (param.from_, hd.to_, hd.token_id, hd.amount) in 
        // check permissions
        let operator = Tezos.sender in 
        let owner = from in 
        let operator_permissions = 
            match Big_map.find_opt (owner, operator, token_id) storage.operators with 
            | None -> 0n
            | Some allowed_qty -> allowed_qty in 
        if ((Tezos.sender <> from) && (operator_permissions < qty)) then (failwith error_FA2_NOT_OPERATOR : storage) else 
        // update operator permissions to reflect this transfer
        let operators = 
            if Tezos.sender <> from // thus this is an operator
            then Big_map.update (owner, operator, token_id) (Some (abs (operator_permissions - qty))) storage.operators
            else storage.operators in
        // check balance
        let sender_token_balance =
            match Big_map.find_opt (from, token_id) storage.ledger with
            | None -> 0n
            | Some token_balance -> token_balance in
        let recipient_balance = 
            match Big_map.find_opt (to, token_id) storage.ledger with
            | None -> 0n
            | Some recipient_token_balance -> recipient_token_balance in
        if (sender_token_balance < qty) then (failwith error_FA2_INSUFFICIENT_BALANCE : storage) else
        // update the ledger
        let ledger = 
            Big_map.update
            (to, token_id)
            (Some (recipient_balance + qty))
                (Big_map.update 
                 (from, token_id) 
                 (Some (abs (sender_token_balance - qty))) 
                 storage.ledger) in 
        let storage = {storage with ledger = ledger ; operators = operators ; } in
        let param = { from_ = from ; txs = tl ; } in 
        transfer_txn (param, storage)

let rec transfer (param, storage : transfer list * storage) : result = 
    match param with 
    | [] -> (([] : operation list), storage)
    | hd :: tl -> 
        let storage = transfer_txn (hd, storage) in 
        transfer (tl, storage)

// the entrypoint to query balance 
// input balance_of is a tuple:
//   * the first entry is a list of the form (owner, token_id) list which queries the balance of owner in the given token id
//   * the second entry is a contract that can receive the list of balances. This list is of the form 
//     (owner, token_id, amount) list = (address * nat * nat) list
//     An example of such a contract is in tests/test-fa2.mligo 
let balance_of (param : balance_of) (storage : storage) : result = 
    let (request_list, callback) = (param.requests, param.callback) in 
    let accumulator = ([] : callback_data list) in
    let ack_list = owner_and_id_to_balance (accumulator, request_list, storage.ledger) in
    let t = Tezos.transaction ack_list 0mutez callback in
    ([t], storage)


// The entrypoint where fa2_owner adds or removes fa2_operator from storage.operators
// * The input is a triple: (owner, operator, id) : address * address * nat
//   This triple is tagged either as Add_operator or Remove_operator
// * Only the token owner can add or remove operators
// * An operator can perform transactions on behalf of the owner
let update_operator (param : update_operator) (storage : storage) : storage = 
    match param with
    | Add_operator o ->
        let (owner, operator, token_id, qty) = (o.owner, o.operator, o.token_id, o.qty) in 
        // check permissions        
        if (Tezos.source <> owner) then (failwith error_PERMISSIONS_DENIED : storage) else
        if operator = owner then (failwith error_COLLISION : storage) else // an owner can't be their own operator 
        // update storage
        let new_qty = 
            let old_qty = 
             match Big_map.find_opt (owner, operator, token_id) storage.operators with 
             | None -> 0n 
             | Some q -> q in 
            old_qty + qty in 
        let storage = {storage with 
            operators = Big_map.update (owner, operator, token_id) (Some new_qty) storage.operators ; } in 
        storage
    | Remove_operator o ->
        let (owner, operator, token_id) = (o.owner, o.operator, o.token_id) in 
        // check permissions
        if (Tezos.sender <> owner) then (failwith error_PERMISSIONS_DENIED : storage) else
        // update storage
        let storage = {storage with 
            operators = Big_map.update (owner,operator,token_id) (None : nat option) storage.operators ; } in 
        storage

let rec update_operators (param, storage : update_operators * storage) : result = 
    match param with
    | [] -> (([] : operation list), storage)
    | hd :: tl -> 
        let storage = update_operator hd storage in 
        update_operators (tl, storage)

// only the carbon contract can mint tokens
// This entrypoint can only be called by the carbon contract
let rec mint_tokens (param, storage : mintburn * storage) : result =
    let minting_list = param in
    match minting_list with 
    | [] -> (([] : operation list), storage)
    | hd :: tl -> 
        let owner = hd.owner in 
        let token_id = hd.token_id in 
        let qty = hd.qty in 
        // check operator
        if Tezos.sender <> storage.carbon_contract then (failwith error_PERMISSIONS_DENIED : result) else 
        // update owner balance
        let owner_balance = 
            match Big_map.find_opt (owner, token_id) storage.ledger with
            | None -> 0n + qty
            | Some ownerPrevBalance -> ownerPrevBalance + qty in
        let storage = {storage with 
            ledger = Big_map.update (owner, token_id) (Some owner_balance) storage.ledger ; } in 
        mint_tokens (tl, storage)

// only the carbon contract can burn tokens
// Like minting, this entrypoint can only be called by the carbon contract
let burn_tokens (param : mintburn) (storage : storage) : transfer = 
    // check permissions
    if Tezos.sender <> storage.carbon_contract then (failwith error_PERMISSIONS_DENIED : transfer) else 
    let burn_addr = ("tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU" : address) in 
    let from = Tezos.source in 
    // transfer the tokens to the burn address
    {
        from_ = from ;
        txs = List.map
            (fun (b : mintburn_data) : transfer_to -> 
                let () = assert (b.owner = from) in 
                {
                    to_ = burn_addr ;
                    token_id = b.token_id ;
                    amount = b.qty ;
                })
            param ;
    }

// The entrypoint to query token metadata
// The input is a tuple: (query_list, callback_contract)
//   * The query list is of token ids and has type `nat list`
//   * The callback contract must have type ((fa2_token_id * token_metadata) list contract)
let get_metadata (param : get_metadata) (storage : storage) : result = 
    let query_list = param.token_ids in 
    let callback = param.callback in 
    let metadata_list = 
        List.map 
        (fun (token_id : nat) : token_metadata -> 
            match Big_map.find_opt token_id storage.token_metadata with 
            | None -> (failwith error_FA2_TOKEN_UNDEFINED : token_metadata) 
            | Some m -> {token_id = token_id ; token_info = m.token_info ; })
        query_list in 
    let op_metadata = Tezos.transaction metadata_list 0tez callback in 
    ([op_metadata] , storage)

// This entrypoint allows project owners to add zones (token ids) to their project
// This transaction has to come from the carbon contract, which has a set of preapproval rules 
// governing this process
// If there is a collision on token ids, this entrypoint will return a failwith
let add_zone (param : token_metadata list) (storage : storage) : result = 
    if Tezos.sender <> storage.owner then (failwith error_PERMISSIONS_DENIED : result) else
    let storage = 
        List.fold_left
        (fun (s, d : storage * token_metadata) -> 
            { s with token_metadata = 
                match Big_map.get_and_update d.token_id (Some d) s.token_metadata with
                | (None, m) -> m
                | (Some _, m) -> (failwith error_COLLISION : (fa2_token_id, token_metadata) big_map) } )
        storage
        param in 
    ([] : operation list), storage


// this entrypoint allows a project owner to update the metadata for their project
let update_contract_metadata (param : contract_metadata) (storage : storage) : result = 
    if Tezos.sender <> storage.owner then (failwith error_PERMISSIONS_DENIED : result) else
    ([] : operation list),
    { storage with metadata = param }


(* =============================================================================
 * Main
 * ============================================================================= *)

let rec main ((entrypoint, storage) : entrypoint * storage) : result =
    match entrypoint with
    | Transfer param ->
        transfer (param, storage)
    | Balance_of param -> 
        balance_of param storage
    | Update_operators param ->
        update_operators (param, storage)
    | Mint param -> 
        mint_tokens (param, storage)
    | Burn param ->
        main (Transfer( [burn_tokens param storage] ), storage)
    | Get_metadata param ->
        get_metadata param storage
    | Add_zone param ->
        add_zone param storage
    | Update_contract_metadata param ->
        update_contract_metadata param storage