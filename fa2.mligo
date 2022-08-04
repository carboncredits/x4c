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
    
    // for upgrades
    previous_contract : address option ; // None if this is the first
    upgraded_contract : address option ; // None if this is current

    // the ledger keeps track of who owns what token
    ledger : (owner , nat) big_map ;

    // an operator can trade tokens on behalf of the fa2_owner
    operators : (operator, nat) big_map;

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

type operator_data = [@layout:comb]{ owner : address ; operator : address ; token_id : nat ; qty : nat ; }
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

type get_metadata = {
    token_ids : nat list ;
    callback : token_metadata list contract ;
}

type update_oracle = {
    new_oracle : address ;
}

type pointer = | Upgraded | Previous | Both
type update_pointers = {
    pointer : pointer ; 
    new_pointer : address option ;
}
type upgrade_contract = address 
type clear_fetched_balance = owner
type oracle_fetch_balance = owner list 

type entrypoint = 
| Transfer of transfer list // transfer tokens 
| Balance_of of balance_of // query an address's balance
| Update_operators of update_operators // change operators for some address
| Mint of mint // mint credits
| Retire of retire // retire credits
| Get_metadata of get_metadata // query the metadata of a given token
| Add_token_id of token_metadata list
| Update_contract_metadata of contract_metadata
| Update_oracle of update_oracle
// for upgrades
| Upgrade_contract of upgrade_contract
| Update_pointers of update_pointers
| Clear_fetched_balance of clear_fetched_balance // for upgrades
| Oracle_fetch_balance of oracle_fetch_balance 


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
let error_ADDRESS_NOT_FOUND = 13n // A (contract) address is not found
let error_CONTRACT_INACTIVE = 14n // the contract has been upgraded

(* =============================================================================
 * Aux Functions
 * ============================================================================= *)

let update_balance (type k) (k : k) (diff : int) (ledger : (k, nat) big_map) : (k, nat) big_map =
    let new_bal =
        let old_bal = match Big_map.find_opt k ledger with | None -> 0n | Some b -> b in
        if old_bal + diff < 0 then (failwith error_INSUFFICIENT_BALANCE : nat) else
        abs(old_bal + diff) in
    Big_map.update k (if new_bal = 0n then None else Some new_bal) ledger

let is_operator (operator : operator) (qty : nat) (operators : (operator, nat) big_map) : bool =
    match Big_map.find_opt operator operators with
    | None -> false
    | Some b -> if qty <= b then true else false

// for upgrades: updates the ledger and clears old balances
let view_and_fetch_balance (param_list : owner list) (storage : storage) : result = 
    match storage.previous_contract with 
    | None -> ([] : operation list), storage // this is the first contract 
    | Some previous_contract_addr ->
        List.fold 
        (fun ((ops, storage), o : result * owner) : result -> 
            match (Tezos.call_view "view_telescoping_balance_of" o previous_contract_addr : (nat option) option) with 
            | None -> ops, storage // there was nothing to view; do nothing 
            | Some v -> (
                match v with 
                | None -> ops, storage // there was nothing to view; do nothing 
                | Some imported_bal -> ( // there is a balance somewhere along 
                    // clear that balance by calling clear_fetched_balance
                    match (Tezos.get_entrypoint_opt "%clear_fetched_balance" previous_contract_addr : clear_fetched_balance contract option) with 
                    | None -> (failwith error_ADDRESS_NOT_FOUND : result)
                    | Some entrypoint_addr -> 
                        ((Tezos.transaction o 0tez entrypoint_addr) :: ops),
                        { storage with ledger = update_balance o (int(imported_bal)) storage.ledger ; }
                )
            )
        )
        param_list 
        (([] : operation list), storage)

(* =============================================================================
 * Entrypoint Functions
 * ============================================================================= *)

// The transfer entrypoint function
let transfer (param : transfer list) (storage : storage) : result = 
    // check the contract is active 
    match storage.upgraded_contract with | Some _ -> (failwith error_CONTRACT_INACTIVE : result) | None -> 
    // execute entrypoint call
    ([] : operation list),
    List.fold
    (fun (storage, p : storage * transfer) : storage ->
        let from = p.from_ in
        List.fold
        (fun (storage, p : storage * transfer_to) : storage ->
            let (to, token_id, qty, operator) = (p.to_, p.token_id, p.amount, (Tezos.get_sender ())) in
            let owner = from in
            // check permissions
            if (Tezos.get_sender ()) <> from && not is_operator { token_owner = owner ; token_operator = operator ; token_id = token_id ; } qty storage.operators
                then (failwith error_PERMISSIONS_DENIED : storage) else
            // update operator permissions to reflect this transfer; fails if not an operator
            let operators =
                if (Tezos.get_sender ()) <> from // thus this is an operator acting
                then update_balance
                    { token_owner = owner ; token_operator = operator ; token_id = token_id ; }
                    (int (qty))
                    storage.operators
                else storage.operators in
            // update the ledger
            let ledger =
                update_balance { token_owner = from ; token_id = token_id ; } (-qty) (
                update_balance { token_owner = to   ; token_id = token_id ; } (int (qty)) storage.ledger ) in
            { storage with ledger = ledger ; operators = operators ; }
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
        let (owner, operator, token_id, qty) = (o.owner, o.operator, o.token_id, o.qty) in
        // check permissions
        if ((Tezos.get_sender ()) <> owner) then (failwith error_PERMISSIONS_DENIED : storage) else
        if operator = owner then (failwith error_COLLISION : storage) else // an owner can't be their own operator
        // update storage
        {storage with operators =
            let new_qty =
                let old_qty =
                    match Big_map.find_opt {token_owner = owner; token_operator = operator; token_id = token_id ;} storage.operators with
                    | None -> 0n
                    | Some q -> q in
                old_qty + qty in
            Big_map.update {token_owner = owner; token_operator = operator; token_id = token_id ;} (Some new_qty) storage.operators ; }
    | Remove_operator o ->
        let (owner, operator, token_id) = (o.owner, o.operator, o.token_id) in
        // check permissions
        if ((Tezos.get_sender ()) <> owner) then (failwith error_PERMISSIONS_DENIED : storage) else
        // update storage
        {storage with
            operators = Big_map.update {token_owner = owner; token_operator = operator; token_id = token_id ;} (None : nat option) storage.operators ; }

let update_operators (param : update_operators) (storage : storage) : result =
    ([] : operation list),
    List.fold update_operator param storage

// This entrypoint can only be called by the admin
let mint_tokens (param : mint) (storage : storage) : result =
    // check permissions and check the contract is active 
    if (Tezos.get_source ()) <> storage.oracle then (failwith error_PERMISSIONS_DENIED : result) else 
    match storage.upgraded_contract with | Some _ -> (failwith error_CONTRACT_INACTIVE : result) | None -> 
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
    // check the contract is active 
    match storage.upgraded_contract with | Some _ -> (failwith error_CONTRACT_INACTIVE : result) | None -> 
    // execute retire
    ([] : operation list),
    List.fold
    (fun (s, p : (storage * retire_tokens)) : storage ->
        // check permissions
        if (Tezos.get_sender ()) <> p.retiring_party && not (is_operator { token_owner = p.retiring_party ; token_operator = (Tezos.get_sender ()) ; token_id = p.token_id ; } p.amount s.operators)
        then (failwith error_PERMISSIONS_DENIED : storage) else
        // update storage
        { storage with
            ledger = update_balance { token_owner = p.retiring_party ; token_id = p.token_id ; } (-p.amount) s.ledger ; } )
    param
    storage

// The entrypoint to query token metadata
let get_metadata (param : get_metadata) (storage : storage) : result =
    let (query, callback) = (param.token_ids, param.callback) in
    let op_metadata =
        Tezos.transaction
        (
            List.map
            (fun (token_id : nat) : token_metadata ->
                match Big_map.find_opt token_id storage.token_metadata with
                | None -> (failwith error_TOKEN_UNDEFINED : token_metadata)
                | Some m -> {token_id = token_id ; token_info = m.token_info ; })
            query
        )
        0tez
        callback in
    ([op_metadata] , storage)

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

// upgrade the FA2 contract address
let upgrade_contract (param : upgrade_contract) (storage : storage) : result = 
    let upgraded_contract = param in 
    // check the contract is active (can only be upgraded once)
    match storage.upgraded_contract with | Some _ -> (failwith error_CONTRACT_INACTIVE : result) | None ->
    // check permissions
    if (Tezos.get_sender ()) <> storage.oracle then (failwith error_PERMISSIONS_DENIED : result) else
    // upgrade, which freezes transfers, mints, and retires from this contract; upgraded contract can lazily port in balances
    ([] : operation list), { storage with upgraded_contract = (Some upgraded_contract) ; }

// contracts in the linked list can update the link list to remove themselves if the ledger is empty
let update_pointers (param : update_pointers) (storage : storage) : result = 
    // update the storage with the new pointer
    //  only the upgraded contract can change the upgraded pointer
    //  and only the previous can change the previous pointer
    match param.pointer with 
    | Previous -> (
        match storage.previous_contract with 
        | None -> (failwith error_PERMISSIONS_DENIED : result) // there is no one that can call this 
        | Some previous_contract_addr -> 
            if Tezos.get_sender() <> previous_contract_addr then (failwith error_PERMISSIONS_DENIED : result) else 
            ([] : operation list), { storage with previous_contract = param.new_pointer } )
    | Upgraded -> (
        match storage.upgraded_contract with 
        | None -> (failwith error_PERMISSIONS_DENIED : result) // there is no one that can call this 
        | Some upgraded_contract_addr ->
            if Tezos.get_sender() <> upgraded_contract_addr then (failwith error_PERMISSIONS_DENIED : result) else 
            ([] : operation list), { storage with upgraded_contract = param.new_pointer } ) 
    | Both -> (
            if Tezos.get_source() <> storage.oracle then (failwith error_PERMISSIONS_DENIED : result) else
            // update the previous_contract pointer of the upgraded contract to be 
            // this contract's upgraded pointer (removing this contract from the linked list)
            let ops = 
                match storage.upgraded_contract with 
                | None -> (failwith error_PERMISSIONS_DENIED : operation list) // contract is active and this should fail anyway
                | Some upgraded_contract_addr -> (
                    match (Tezos.get_entrypoint_opt "%update_pointers" upgraded_contract_addr : update_pointers contract option) with 
                    | None -> (failwith error_ADDRESS_NOT_FOUND : operation list)
                    | Some addr_entrypoint -> 
                        // our list ops now has one element
                        (Tezos.transaction { pointer = Previous ; new_pointer = storage.previous_contract ; } 0tez addr_entrypoint) :: ([] : operation list) ) in 
            // update the upgraded_contract pointer of the previous contract to be 
            // this contract's upgraded pointer (removing this contract from the linked list)
            let ops = 
                match storage.previous_contract with 
                | None -> ops // this was the beginning of the linked list, and the upgraded contract now is the beginning of the linked list due to the above operation
                | Some previous_contract_addr -> (
                    match (Tezos.get_entrypoint_opt "%update_pointers" previous_contract_addr : update_pointers contract option) with 
                    | None -> (failwith error_ADDRESS_NOT_FOUND : operation list)
                    | Some addr_entrypoint -> 
                        (Tezos.transaction { pointer = Upgraded ; new_pointer = storage.upgraded_contract ; } 0tez addr_entrypoint) :: ops )
            in ops, storage )

// upgrades can lazily port the token balance
let clear_fetched_balance (param : clear_fetched_balance) (storage : storage) : result = 
    let owner = param in 
    // check that this contract is inactive 
    match storage.upgraded_contract with | None -> (failwith error_PERMISSIONS_DENIED : result) | Some upgraded_contract_addr ->    
    // check that the upgraded contract is the sender
    if (Tezos.get_sender ()) <> upgraded_contract_addr then (failwith error_PERMISSIONS_DENIED : result) else
    // fetch the balance and clear it from the ledger (this has now been fetched)
    let (bal_option, storage) : nat option * storage = 
        let (b, ledger) = Big_map.get_and_update owner (None : nat option) storage.ledger in 
        (b, { storage with ledger = ledger ; }) in (
    // if there was no balance to fetch, we need to check the previous contract 
    match (bal_option : nat option) with 
    | Some _ -> ([] : operation list), storage // we found and cleared the balance
    | None -> (
        // there might be balance in a previous contract 
        match storage.previous_contract with 
        | None -> ([] : operation list), storage // this is the first contract 
        | Some previous_contract_addr -> (
            match (Tezos.get_entrypoint_opt "%clear_fetched_balance" previous_contract_addr : clear_fetched_balance contract option) with
            | None -> (failwith error_ADDRESS_NOT_FOUND : result)
            | Some addr_entrypoint -> 
                // recursively call %clear_fetched_balance until you've cleared the balance
                let op_clear_fetched_balance = Tezos.transaction param 0tez addr_entrypoint in 
                [ op_clear_fetched_balance ; ], storage ) ) )

// an oracle can fetch user balances and unlinks the most recent upgrade from the linked list
let oracle_fetch_balance (param : oracle_fetch_balance) (storage : storage) : result = 
    // check permissions 
    if Tezos.get_sender() <> storage.oracle then (failwith error_PERMISSIONS_DENIED : result) else 
    // view and fetch the balance 
    let (op_list, storage) = view_and_fetch_balance param storage in 
    // remove the most recent upgrade from the linked list 
    match storage.previous_contract with 
    | None -> (op_list, storage)
    | Some previous_contract_addr -> (
        match (Tezos.get_entrypoint_opt "%update_pointers" previous_contract_addr : update_pointers contract option) with 
        | None -> (failwith error_ADDRESS_NOT_FOUND : result)
        | Some entrypoint_addr -> 
            (Tezos.transaction { pointer = Both ; new_pointer = (None : address option) ; } 0tez entrypoint_addr) :: op_list,
            storage )

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

// the contract's update status
[@view] let view_is_active (_, storage : unit * storage) : bool = 
    match storage.upgraded_contract with | None -> true | Some _ -> false

// for upgrades -- the recursive backwards call to find storage (and later to lazily import it)
[@view] let view_telescoping_balance_of (owner, storage : owner * storage) : nat option = 
    // first search local storage 
    match Big_map.find_opt owner storage.ledger with 
    | Some n -> (Some n)
    | None -> (
        // if nothing shows up, recursively search the previous contract's storage
        match storage.previous_contract with 
        | None -> (None : nat option) // this is the first storage contract, all balances are cleared
        | Some addr -> (
            match (Tezos.call_view "view_telescoping_balance_of" owner addr : (nat option) option) with 
            // if it returns None, this means there is no storage contract with a value for this key
            | None -> (None : nat option)
            // if it returns Some b then somewhere in the backwards chain of storage contracts n was stored
            | Some nat_option -> nat_option ) )

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
    | Get_metadata param ->
        get_metadata param storage
    | Add_token_id param ->
        add_token_id param storage
    | Update_contract_metadata param ->
        update_contract_metadata param storage
    | Update_oracle param ->
        update_oracle param storage
    // for upgrades
    | Upgrade_contract param ->
        upgrade_contract param storage
    | Update_pointers param -> 
        update_pointers param storage 
    | Clear_fetched_balance param -> 
        clear_fetched_balance param storage
    | Oracle_fetch_balance param -> 
        oracle_fetch_balance param storage