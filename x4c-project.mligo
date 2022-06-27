(* An FA2 contract for carbon tokens *)
(* FA2 Proposal TZIP: https://gitlab.com/tezos/tzip/-/blob/master/proposals/tzip-12/tzip-12.md *)
(* FA2 Standard: https://tezos.b9lab.com/fa2 *)


(* =============================================================================
 * Storage
 * ============================================================================= *)

type token_id = nat
type token_metadata = [@layout:comb]{
    token_id : nat ; 
    token_info : (string, bytes) map ;
}
type contract_metadata = (string, bytes) big_map
type token_owner = [@layout:comb]{
    token_owner : address ; 
    token_id : nat ;
}
type operator = [@layout:comb]{
    token_owner : address ; 
    token_id : nat ;
    operator : address ;
}
type retired_token = [@layout:comb]{
    token_owner : address ; 
    token_id : nat ; 
    time_retired : timestamp ;
}
type retired_tokens = retired_token list 

type storage = {
    owner : address ; // the project owner
    x4c_oracle : address ;
    ledger : (token_owner, nat) big_map ; 
    retired_tokens : (address, retired_tokens) big_map ;
    operators : (operator, nat) big_map; 
    token_metadata : (token_id, token_metadata) big_map;
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

type request = [@layout:comb]{ token_owner : address ; token_id : nat ; }
type callback_data = [@layout:comb]{ request : request ; balance : nat ; }
type balance_of = [@layout:comb]{
    requests : request list ; 
    callback : callback_data list contract ;
}

type operator_data = [@layout:comb]{ token_owner : address ; operator : address ; token_id : nat ; qty : nat ; }
type update_operator = 
    | Add_operator of operator_data
    | Remove_operator of operator_data
type update_operators = update_operator list

type mintburn_data = { token_owner : address ; token_id : nat ; qty : nat ; }
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
let error_COLLISION = 12n // A collision in storage 
let error_CALL_VIEW_FAILED = 13n // Fail code for contract views 

(* =============================================================================
 * Aux Functions
 * ============================================================================= *)

// an auxiliary function for querying an address's balance
let rec owner_and_id_to_balance (param : (callback_data list) * (request list) * ((token_owner , nat) big_map)) : callback_data list =
    let (accumulator, request_list, ledger) = param in
    match request_list with
    | [] -> accumulator 
    | h :: t -> 
        let (token_owner, token_id) = (h.token_owner, h.token_id) in 
        let bal =
            match Big_map.find_opt { token_owner = token_owner ; token_id = token_id } ledger with 
            | None -> 0n
            | Some owner_balance -> owner_balance in
        let request = { token_owner = token_owner ; token_id = token_id ; } in
        let accumulator = { request = request ; balance = bal ; } :: accumulator in
        owner_and_id_to_balance (accumulator, t, ledger) 

// checks to see if an address is one of the proxy contracts of the oracle contract
let is_oracle_proxy (addr : address) (x4c_oracle : address) : bool = 
    match (Tezos.call_view "is_proxy" addr x4c_oracle : bool option) with 
    | None -> (failwith error_CALL_VIEW_FAILED : bool)
    | Some b -> b

(* =============================================================================
 * Entrypoint Functions
 * ============================================================================= *)

(* ====== 
    Transfers
 * ====== *)
let rec transfer_txn (param , storage : transfer * storage) : storage = 
    match param.txs with
    | [] -> storage
    | hd :: tl ->
        let (from, to, token_id, qty) = (param.from_, hd.to_, hd.token_id, hd.amount) in 
        // check permissions
        let (operator, token_owner) = (Tezos.sender, from) in 
        let operator_permissions = 
            match Big_map.find_opt { token_owner = token_owner ; operator = operator ; token_id = token_id } storage.operators with 
            | None -> 0n 
            | Some allowed_qty -> allowed_qty in 
        if ((Tezos.source <> from) && (Tezos.sender <> from) && (operator_permissions < qty)) 
            then (failwith error_FA2_NOT_OPERATOR : storage) else 
        // update operator permissions to reflect this transfer
        let operators = 
            if (Tezos.source <> from) && (Tezos.sender <> from) // thus this is an operator
            then Big_map.update { token_owner = token_owner ; operator = operator ; token_id = token_id } (Some (abs (operator_permissions - qty))) storage.operators
            else storage.operators in
        // check balance
        let sender_token_balance =
            match Big_map.find_opt { token_owner = from ; token_id = token_id } storage.ledger with
            | None -> 0n
            | Some token_balance -> token_balance in
        let recipient_balance = 
            match Big_map.find_opt { token_owner = to ; token_id = token_id } storage.ledger with
            | None -> 0n
            | Some recipient_token_balance -> recipient_token_balance in
        if (sender_token_balance < qty) then (failwith error_FA2_INSUFFICIENT_BALANCE : storage) else
        // update the ledger
        let ledger = 
            Big_map.update
            { token_owner = to ; token_id = token_id }
            (Some (recipient_balance + qty))
                (Big_map.update 
                 { token_owner = from ; token_id = token_id } 
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

(* ====== 
    Balance query (deprecated by contract views)
 * ====== *)
let balance_of (param : balance_of) (storage : storage) : result = 
    let (request_list, callback) = (param.requests, param.callback) in 
    let accumulator = ([] : callback_data list) in
    let ack_list = owner_and_id_to_balance (accumulator, request_list, storage.ledger) in
    let t = Tezos.transaction ack_list 0mutez callback in
    ([t], storage)


(* ====== 
    Update operators. Operators can spend tokens on the owner's behalf
 * ====== *)
let update_operator (param : update_operator) (storage : storage) : storage = 
    match param with
    | Add_operator o ->
        let (token_owner, operator, token_id, qty) = (o.token_owner, o.operator, o.token_id, o.qty) in 
        // check permissions        
        if (Tezos.source <> token_owner) then (failwith error_PERMISSIONS_DENIED : storage) else
        if operator = token_owner then (failwith error_COLLISION : storage) else // an owner can't be their own operator 
        // update storage
        let new_qty = 
            let old_qty = 
             match Big_map.find_opt { token_owner = token_owner ; operator = operator ; token_id = token_id } storage.operators with 
             | None -> 0n 
             | Some q -> q in 
            old_qty + qty in 
        let storage = {storage with 
            operators = Big_map.update { token_owner = token_owner ; operator = operator ; token_id = token_id } (Some new_qty) storage.operators ; } in 
        storage
    | Remove_operator o ->
        let (token_owner, operator, token_id) = (o.token_owner, o.operator, o.token_id) in 
        // check permissions
        if (Tezos.sender <> token_owner) then (failwith error_PERMISSIONS_DENIED : storage) else
        // update storage
        let storage = {storage with 
            operators = Big_map.update { token_owner = token_owner ; operator = operator ; token_id = token_id } (None : nat option) storage.operators ; } in 
        storage

let rec update_operators (param, storage : update_operators * storage) : result = 
    match param with
    | [] -> (([] : operation list), storage)
    | hd :: tl -> 
        let storage = update_operator hd storage in 
        update_operators (tl, storage)

(* ====== 
    Mint tokens. Only the oracle contract can mint tokens 
 * ====== *)
let rec mint_tokens (param, storage : mintburn * storage) : result =
    // only the oracle contract can mint tokens
    if not is_oracle_proxy Tezos.sender storage.x4c_oracle then (failwith error_PERMISSIONS_DENIED : result) else 
    match param with 
    | [] -> (([] : operation list), storage)
    | hd :: tl -> 
        let (token_owner, token_id, qty) = (hd.token_owner, hd.token_id, hd.qty) in 
        // check operator
        if not is_oracle_proxy Tezos.sender storage.x4c_oracle then (failwith error_PERMISSIONS_DENIED : result) else 
        // update owner balance
        let owner_balance = 
            match Big_map.find_opt { token_owner = token_owner ; token_id = token_id } storage.ledger with
            | None -> 0n + qty
            | Some ownerPrevBalance -> ownerPrevBalance + qty in
        let storage = {storage with 
            ledger = Big_map.update { token_owner = token_owner ; token_id = token_id } (Some owner_balance) storage.ledger ; } in 
        mint_tokens (tl, storage)

(* ====== 
    Burn tokens. Only the oracle contract can burn tokens 
 * ====== *)
let rec burn_tokens (param, storage : mintburn * storage) : result = 
    // only the oracle contract can burn tokens
    if not is_oracle_proxy Tezos.sender storage.x4c_oracle then (failwith error_PERMISSIONS_DENIED : result) else 
    match param with 
    | [] -> (([] : operation list), storage)
    | hd :: tl -> 
        let (token_owner, token_id, qty) = (hd.token_owner, hd.token_id, hd.qty) in 
        // check operator
        if not is_oracle_proxy Tezos.sender storage.x4c_oracle then (failwith error_PERMISSIONS_DENIED : result) else 
        // update owner balance
        let owner_balance = 
            match Big_map.find_opt { token_owner = token_owner ; token_id = token_id } storage.ledger with
            | None -> if 0n - qty < 0 then (failwith error_FA2_INSUFFICIENT_BALANCE : nat) else 0n
            | Some b -> if b - qty < 0 then (failwith error_FA2_INSUFFICIENT_BALANCE : nat) else abs(b - qty) in
        // register the retired tokens 
        let retired_tokens = 
            let new_retired_tokens = 
                let new_retired_token = { token_owner = token_owner ; token_id = token_id ; time_retired = Tezos.now } in
                match Big_map.find_opt token_owner storage.retired_tokens with 
                | None -> [ new_retired_token ; ]
                | Some l -> new_retired_token :: l in
            Big_map.update token_owner (Some new_retired_tokens) storage.retired_tokens in 
        // update storage and iterate
        let storage = {storage with 
            ledger = Big_map.update { token_owner = token_owner ; token_id = token_id } (Some owner_balance) storage.ledger ; 
            retired_tokens = retired_tokens ; 
        } in 
        burn_tokens (tl, storage)

(* ====== 
    Query the metadata. Deprecated with contract views.
 * ====== *)
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

(* ====== 
    Add a zone (a new token ID). Only can be done by the oracle contract
 * ====== *)
let add_zone (param : token_metadata list) (storage : storage) : result = 
    if Tezos.sender <> storage.owner then (failwith error_PERMISSIONS_DENIED : result) else
    let storage = 
        List.fold_left
        (fun (s, d : storage * token_metadata) -> 
            { s with token_metadata = 
                match Big_map.get_and_update d.token_id (Some d) s.token_metadata with
                | (None, m) -> m
                | (Some _, m) -> (failwith error_COLLISION : (token_id, token_metadata) big_map) } )
        storage
        param in 
    ([] : operation list), storage


(* ====== 
    Update contract metadata. The project owner can change the project metadata
 * ====== *)
let update_contract_metadata (param : contract_metadata) (storage : storage) : result = 
    if Tezos.sender <> storage.owner then (failwith error_PERMISSIONS_DENIED : result) else
    ([] : operation list),
    { storage with metadata = param }

(* =============================================================================
 * Contract Views
 * ============================================================================= *)

[@view] let view_has_token_id (token_id , storage : nat * storage) : bool = 
    Big_map.mem token_id storage.token_metadata

[@view] let view_balance_of (token_owner , storage : token_owner * storage ) : nat =
    match Big_map.find_opt token_owner storage.ledger with
    | None -> 0n 
    | Some b -> b

[@view] let view_token_metadata (m, storage : token_id * storage) : token_metadata option = 
    Big_map.find_opt m storage.token_metadata

[@view] let view_metadata (m, storage : string * storage) : bytes option =
    Big_map.find_opt m storage.metadata

[@view] let view_operators (o, storage : operator * storage) : nat option =
    Big_map.find_opt o storage.operators

[@view] let view_owner (_, storage : unit * storage) : address = storage.owner

(* =============================================================================
 * Main
 * ============================================================================= *)

let main ((entrypoint, storage) : entrypoint * storage) : result =
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
        burn_tokens (param, storage)
    | Get_metadata param ->
        get_metadata param storage
    | Add_zone param ->
        add_zone param storage
    | Update_contract_metadata param ->
        update_contract_metadata param storage