(* An FA2 contract *)
(* FA2 Proposal TZIP: https://gitlab.com/tezos/tzip/-/blob/master/proposals/tzip-12/tzip-12.md *)
(* FA2 Standard: https://tezos.b9lab.com/fa2 *)

(* =============================================================================
 * Storage
 * ============================================================================= *)

type token_id = nat

type owner = [@layout:comb]{ token_owner : address ; token_id : nat ; }
type operator = [@layout:comb]{
    token_owner : address ;
    token_operator : address ;
    token_id : nat ;
}

type token_metadata = [@layout:comb]{ token_id : nat ; token_info : (string, bytes) map ; }
type contract_metadata = (string, bytes) big_map

type storage = {
    // oracle / admin : has minting permissions and can edit the contract's metadata
    oracle : address ;

    // the ledger keeps track of who owns what token
    ledger : (owner , nat) big_map ;

    // an operator can trade tokens on behalf of the fa2_owner
    operators : operator set;
    
    // token metadata for each token type supported by this contract
    token_metadata : (token_id, token_metadata) big_map;
    // contract metadata
    metadata : (string, bytes) big_map;
}

type result = (operation list) * storage


(* =============================================================================
 * Entrypoint Type Definition
 * ============================================================================= *)
type transfer_to = [@layout:comb]{ to_ : address ; token_id : nat ; amount : nat ; }
type transfer = [@layout:comb]{ from_ : address; txs : transfer_to list; }

type request = [@layout:comb]{ token_owner : address ; token_id : nat ; }
type callback_data = [@layout:comb]{ request : request ; balance : nat ; }
type balance_of = [@layout:comb]{ requests : request list ; callback : callback_data list contract ; }

type operator_data = [@layout:comb]{ owner : address ; operator : address ; token_id : nat ; }
type update_operator = 
    | Add_operator of operator_data
    | Remove_operator of operator_data
type update_operators = update_operator list

type mint_data = { owner : address ; token_id : nat ; qty : nat ; }
type mint = mint_data list

type retire_tokens = {
    retiring_party : address ;
    token_id : nat ;
    amount : nat ;
    retiring_data : bytes ;
}
type retire = retire_tokens list

type update_oracle = {
    new_oracle : address ;
}

type entrypoint =
| Transfer of transfer list // transfer tokens
| Balance_of of balance_of // query an address's balance
| Update_operators of update_operators // change operators for some address
| Mint of mint // mint credits
| Retire of retire // retire credits
| Add_token_id of token_metadata list
| Update_contract_metadata of contract_metadata
| Update_oracle of update_oracle


(* =============================================================================
 * Error codes
 * ============================================================================= *)

let error_TOKEN_UNDEFINED = 0n // One of the specified token_ids is not defined within the FA2 contract
let error_INSUFFICIENT_BALANCE = 1n // A token owner does not have sufficient balance to transfer tokens from owner's account
let error_TX_DENIED = 2n // A transfer failed because of fa2_operatortransfer_policy == No_transfer
let error_NOT_OWNER = 3n // A transfer failed because fa2_operatortransfer_policy == fa2_ownertransfer and it is invoked not by the token owner
let error_NOT_OPERATOR = 4n // A transfer failed because fa2_operatortransfer_policy == fa2_owneror_fa2_operatortransfer and it is invoked neither by the token owner nor a permitted operator
let error_OPERATORS_UNSUPPORTED = 5n // update_operators entrypoint is invoked and fa2_operatortransfer_policy is No_transfer or fa2_ownertransfer
let error_RECEIVER_HOOK_FAILED = 6n // The receiver hook failed. This error MUST be raised by the hook implementation
let error_SENDER_HOOK_FAILED = 7n // The sender failed. This error MUST be raised by the hook implementation
let error_RECEIVER_HOOK_UNDEFINED = 8n // Receiver hook is required by the permission behavior, but is not implemented by a receiver contract
let error_SENDER_HOOK_UNDEFINED = 9n // Sender hook is required by the permission behavior, but is not implemented by a sender contract
let error_PERMISSIONS_DENIED = 10n // General catch-all for operator-related permission errors
let error_ID_ALREADY_IN_USE = 11n // A token ID can only be used once, error if a user wants to add a token ID that's already there
let error_COLLISION = 12n // A collision in storage

(* =============================================================================
 * Aux Functions
 * ============================================================================= *)

let update_balance (type k) (k : k) (diff : int) (ledger : (k, nat) big_map) : (k, nat) big_map =
    let new_bal =
        let old_bal = match Big_map.find_opt k ledger with | None -> 0n | Some b -> b in
        if old_bal + diff < 0 then (failwith error_INSUFFICIENT_BALANCE : nat) else
        abs(old_bal + diff) in
    Big_map.update k (if new_bal = 0n then None else Some new_bal) ledger

let is_operator (operator : operator) (operators : operator set) : bool = 
    Set.mem operator operators

(* =============================================================================
 * Entrypoint Functions
 * ============================================================================= *)

// The transfer entrypoint function
let transfer (param : transfer list) (storage : storage) : result =
    ([] : operation list),
    List.fold
    (fun (storage, p : storage * transfer) : storage -> 
        let from = p.from_ in 
        List.fold 
        (fun (storage, p : storage * transfer_to) : storage -> 
            let (to, token_id, qty, operator) = (p.to_, p.token_id, p.amount, (Tezos.get_sender ())) in 
            let owner = from in 
            // check permissions 
            if (Tezos.get_sender ()) <> from && not is_operator { token_owner = owner ; token_operator = operator ; token_id = token_id ; } storage.operators 
                then (failwith error_PERMISSIONS_DENIED : storage) else 
            // update the ledger
            let ledger = 
                update_balance { token_owner = from ; token_id = token_id ; } (-qty) ( 
                update_balance { token_owner = to   ; token_id = token_id ; } (int (qty)) storage.ledger ) in 
            { storage with ledger = ledger ; }
        )
        p.txs
        storage
    )
    param
    storage

// the entrypoint to query balance
let balance_of (param : balance_of) (storage : storage) : result =
    let (request_list, callback) = (param.requests, param.callback) in
    let op_balanceOf =
        Tezos.transaction
        (
            List.map
            (
                fun (r : request) ->
                { request = r ;
                  balance =
                    match Big_map.find_opt r storage.ledger with | None -> 0n | Some b -> b ; }
            )
            request_list
        )
        0mutez
        callback in
    ([op_balanceOf], storage)

// The entrypoint where fa2_owner adds or removes fa2_operator from storage.operators
let update_operator (storage, param : storage * update_operator) : storage =
    match param with
    | Add_operator o ->
        let (owner, operator, token_id) = (o.owner, o.operator, o.token_id) in 
        // check permissions        
        if ((Tezos.get_sender ()) <> owner) then (failwith error_PERMISSIONS_DENIED : storage) else
        if operator = owner then (failwith error_COLLISION : storage) else // an owner can't be their own operator
        // update storage
        {storage with operators = 
            Set.add {token_owner = owner; token_operator = operator; token_id = token_id ;} storage.operators ; }
    | Remove_operator o ->
        let (owner, operator, token_id) = (o.owner, o.operator, o.token_id) in
        // check permissions
        if ((Tezos.get_sender ()) <> owner) then (failwith error_PERMISSIONS_DENIED : storage) else
        // update storage
        {storage with operators =
            Set.remove {token_owner = owner; token_operator = operator; token_id = token_id ;} storage.operators ; }
        
let update_operators (param : update_operators) (storage : storage) : result = 
    ([] : operation list),
    List.fold update_operator param storage

// This entrypoint can only be called by the admin
let mint_tokens (param : mint) (storage : storage) : result =
    // check permissions
    if (Tezos.get_source ()) <> storage.oracle then (failwith error_PERMISSIONS_DENIED : result) else
    // mint tokens
    ([] : operation list),
    List.fold
    (fun (s, p : storage * mint_data) : storage ->
        // check that token id exists
        if not Big_map.mem p.token_id storage.token_metadata then (failwith error_TOKEN_UNDEFINED : storage) else
        // update storage
        { storage with
            ledger = update_balance { token_owner = p.owner ; token_id = p.token_id ; } (int (p.qty)) s.ledger ; } )
    param
    storage

// retire tokens
let retire_tokens (param : retire) (storage : storage) : result =
    ([] : operation list),
    List.fold 
    (fun (s, p : (storage * retire_tokens)) : storage -> 
        // check permissions 
        if (Tezos.get_sender ()) <> p.retiring_party && not (is_operator { token_owner = p.retiring_party ; token_operator = (Tezos.get_sender ()) ; token_id = p.token_id ; } s.operators) 
        then (failwith error_PERMISSIONS_DENIED : storage) else
        // update storage
        { storage with
            ledger = update_balance { token_owner = p.retiring_party ; token_id = p.token_id ; } (-p.amount) s.ledger ; } )
    param
    storage

// This entrypoint allows the admin to add token ids to their contract
// If there is a collision on token ids, this entrypoint will return a failwith
let add_token_id (param : token_metadata list) (storage : storage) : result =
    if (Tezos.get_sender ()) <> storage.oracle then (failwith error_PERMISSIONS_DENIED : result) else
    ([] : operation list),
    List.fold_left
    (fun (s, d : storage * token_metadata) ->
        { s with token_metadata =
            match Big_map.get_and_update d.token_id (Some d) s.token_metadata with
            | (None, m) -> m
            | (Some _, m) -> (failwith error_COLLISION : (token_id, token_metadata) big_map) } )
    storage
    param

// this entrypoint allows the admin to update the contract metadata
let update_contract_metadata (param : contract_metadata) (storage : storage) : result =
    if (Tezos.get_sender ()) <> storage.oracle then (failwith error_PERMISSIONS_DENIED : result) else
    ([] : operation list),
    { storage with metadata = param }


// entrypoint for the oracle to be updated
let update_oracle (param : update_oracle) (storage : storage) : result =
    if (Tezos.get_sender ()) <> storage.oracle then (failwith error_PERMISSIONS_DENIED : result) else
    ([] : operation list),
    { storage with oracle = param.new_oracle ; }


(* =============================================================================
 * Contract Views
 * ============================================================================= *)

// contract view for balances
[@view] let view_balance_of (o, storage : owner * storage) : nat =
    let owner : owner = { token_owner = o.token_owner ; token_id = o.token_id ; } in
    match Big_map.find_opt owner storage.ledger with
    | None -> 0n
    | Some b -> b

// contract view for metadata
[@view] let view_get_metadata (token_id, storage : nat * storage) : token_metadata =
    match Big_map.find_opt token_id storage.token_metadata with
    | None -> (failwith error_TOKEN_UNDEFINED : token_metadata)
    | Some m -> {token_id = token_id ; token_info = m.token_info ; }

(* =============================================================================
 * Main
 * ============================================================================= *)

let rec main ((entrypoint, storage) : entrypoint * storage) : result =
    match entrypoint with
    | Transfer param ->
        transfer param storage
    | Balance_of param ->
        balance_of param storage
    | Update_operators param ->
        update_operators param storage
    | Mint param ->
        mint_tokens param storage
    | Retire param ->
        retire_tokens param storage
    | Add_token_id param ->
        add_token_id param storage
    | Update_contract_metadata param ->
        update_contract_metadata param storage
    | Update_oracle param ->
        update_oracle param storage