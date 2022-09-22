(*****
    The Cambridge Custody Contract
    This records who we are holding on behalf of, what balances, emits txns to buy etc
 *****)

(* =============================================================================
 * Storage
 * ============================================================================= *)

type token = {
    token_address : address ;
    token_id : nat ;
}
type owner = {
    kyc : bytes ; // kyc data
    token : token ;
}
type operator = [@layout:comb]{
    token_owner : bytes ;
    token_operator : address ;
    token_id : nat ;
}

type qty = nat
type external_owner = [@layout:comb]{ token_owner : address ; token_id : nat ; }

type storage = {
    // the contract admin
    custodian : address ;

    // the ledger keeps track of who we own credits on behalf of
    ledger : (owner , qty) big_map ;
    external_ledger : (token, nat) big_map ;

    // an operator can trade tokens on behalf of the fa2_owner
    operators : operator set;

    // contract metadata
    metadata : (string, bytes) big_map ;
}

type result = operation list * storage


(* =============================================================================
 * Entrypoint Type Definition
 * ============================================================================= *)

type internal_transfer_to = [@layout:comb]{ to_ : bytes ; token_id : nat ; amount : nat ; }
type internal_transfer = [@layout:comb]{ from_ : bytes ; token_address : address ; txs : internal_transfer_to list; }

type external_transfer_to = [@layout:comb]{ to_ : address ; token_id : nat ; amount : nat ; }
type external_transfer_batch = [@layout:comb]{ from_ : bytes ; txs : external_transfer_to list; }
type external_transfer = [@layout:comb]{ token_address : address ; txn_batch : external_transfer_batch list ; }

type transfer_to = [@layout:comb]{ to_ : address ; token_id : nat ; amount : nat ; }
type transfer = [@layout:comb]{ from_ : address ; txs : transfer_to list; }

type internal_mint = { token_id : nat ; token_address : address ; }

type operator_data = [@layout:comb]{ token_owner : bytes ; token_operator : address ; token_id : nat ; }
type update_internal_operator =
    | Add_operator of operator_data
    | Remove_operator of operator_data
type update_internal_operators = update_internal_operator list

type internal_retire_data = {
    retiring_party_kyc : bytes ;
    token_id : nat ;
    amount : nat ;
    retiring_data : bytes ;
}
type internal_retire = { token_address : address ; txs : internal_retire_data list ; }

type external_retire = {
    retiring_party : address ;
    token_id : nat ;
    amount : nat ;
    retiring_data : bytes ;
}

type entrypoint =
| Internal_transfer of internal_transfer list
| Internal_mint of internal_mint list
| External_transfer of external_transfer list
| Update_internal_operators of update_internal_operators // change operators for some address
| Retire of internal_retire list

(* =============================================================================
 * Error Codes
 * ============================================================================= *)

let error_PERMISSIONS_DENIED = 0n
let error_ADDRESS_NOT_FOUND = 1n
let error_INSUFFICIENT_BALANCE = 2n
let error_CALL_VIEW_FAILED = 3n

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

let internal_transfer (param : internal_transfer list) (storage : storage) : result =
    ([] : operation list),
    List.fold
    (fun (storage, p_1 : storage * internal_transfer) : storage ->
        List.fold
        (fun (storage, p_2 : storage * internal_transfer_to) : storage ->
            // check permissions
            if (Tezos.get_sender ()) <> storage.custodian && not is_operator { token_owner = p_1.from_ ; token_operator = (Tezos.get_sender ()) ; token_id = p_2.token_id ; } storage.operators
                        then (failwith error_PERMISSIONS_DENIED : storage) else
            // update the ledger
            let token : token = { token_address = p_1.token_address ; token_id = p_2.token_id ; } in
            { storage with
                ledger =
                    update_balance { kyc = p_1.from_ ; token = token ; } (-p_2.amount) (
                    update_balance { kyc = p_2.to_   ; token = token ; } (int (p_2.amount)) storage.ledger ) ;
            }
        )
        p_1.txs
        storage
    )
    param
    storage

let internal_mint (param : internal_mint list) (storage : storage) : result =
    if (Tezos.get_sender ()) <> storage.custodian then (failwith error_PERMISSIONS_DENIED : result) else
    // port in tokens
    ([] : operation list),
    List.fold
    (fun (storage, p : storage * internal_mint) : storage ->
        let external_internal_diff =
            let external_balance =
                match (Tezos.call_view "view_balance_of" ({ token_owner = (Tezos.get_self_address ()) ; token_id = p.token_id ; } : external_owner) p.token_address : nat option) with
                | None -> (failwith error_CALL_VIEW_FAILED : nat) | Some b -> b in
            let internal_balance =
                match Big_map.find_opt p storage.external_ledger with
                | None -> 0n | Some b -> b in
            external_balance - internal_balance in
        if external_internal_diff < 0 then (failwith error_INSUFFICIENT_BALANCE : storage) else
        { storage with
            ledger = update_balance { kyc = (Bytes.pack "self") ; token = p ; } external_internal_diff storage.ledger ;
            external_ledger = update_balance p external_internal_diff storage.external_ledger ;
        } )
    param
    storage

// triggers a transfer in the FA2 contract
let external_transfer (param : external_transfer list) (storage : storage) : result =
    if (Tezos.get_sender ()) <> storage.custodian then (failwith error_PERMISSIONS_DENIED : result) else
    // decreases internal balance
    let storage =
        List.fold
        (fun (storage, p_0 : storage * external_transfer) : storage ->
            List.fold
            (fun (storage, p_1 : storage * external_transfer_batch) : storage ->
                List.fold
                (fun (storage, p_2 : storage * external_transfer_to) : storage ->
                    let token = { token_address = p_0.token_address ; token_id = p_2.token_id ; } in
                    { storage with
                        ledger =
                            update_balance { kyc = p_1.from_ ; token = token ; } (-p_2.amount) storage.ledger ;
                        external_ledger =
                            update_balance token (-p_2.amount) storage.external_ledger ;
                    } )
                p_1.txs
                storage )
            p_0.txn_batch
            storage )
        param
        storage in
    // emits a transfer function
    let ops_external_transfer : operation list =
        List.map
        (fun (p : external_transfer) : operation ->
            let txndata_external_transfer : transfer list =
                List.map
                (fun (p : external_transfer_batch) : transfer ->
                    { from_ = (Tezos.get_self_address ()) ; txs = p.txs ; } )
                p.txn_batch in
            let entrypoint_external_transfer =
                match (Tezos.get_entrypoint_opt "%transfer" p.token_address : transfer list contract option) with
                | None -> (failwith error_ADDRESS_NOT_FOUND : transfer list contract)
                | Some c -> c in
            Tezos.transaction txndata_external_transfer 0tez entrypoint_external_transfer )
        param in
    ops_external_transfer, storage

let update_internal_operator (storage, param : storage * update_internal_operator) : storage =
    match param with
    | Add_operator o ->
        let (token_owner, token_operator, token_id) = (o.token_owner, o.token_operator, o.token_id) in
        // update storage
        {storage with operators =
            Set.add {token_owner = token_owner; token_operator = token_operator; token_id = token_id ;} storage.operators ; }
    | Remove_operator o ->
        let (token_owner, token_operator, token_id) = (o.token_owner, o.token_operator, o.token_id) in
        // update storage
        {storage with operators =
            Set.remove {token_owner = token_owner; token_operator = token_operator; token_id = token_id ;} storage.operators ; }

let update_internal_operators (param : update_internal_operators) (storage : storage) : result =
    if ((Tezos.get_sender ()) <> storage.custodian) then (failwith error_PERMISSIONS_DENIED : result) else
    ([] : operation list),
    List.fold update_internal_operator param storage

let retire (param : internal_retire list) (storage : storage) : result =
    // update internal ledger
    let storage =
        List.fold
        (fun (storage, p_1 : storage * internal_retire) : storage ->
            List.fold
            (fun (storage, p_2 : storage * internal_retire_data) : storage ->
                if (Tezos.get_sender ()) <> storage.custodian && not is_operator { token_owner = p_2.retiring_party_kyc ; token_operator = (Tezos.get_sender ()) ; token_id = p_2.token_id ; } storage.operators
                    then (failwith error_PERMISSIONS_DENIED : storage) else
                let token = { token_address = p_1.token_address ; token_id = p_2.token_id ; } in
                { storage with
                    ledger =
                        update_balance
                        { kyc = p_2.retiring_party_kyc ; token = token ; }
                        (- p_2.amount)
                        storage.ledger ;
                    external_ledger =
                        update_balance token (-p_2.amount) storage.external_ledger ; } )
            p_1.txs
            storage )
        param
        storage in
    // Send a retire transaction to the FA2 contract, and to emit the retirement data for the frontend
    let ops_retire_tokens =
        List.map
        (fun (p : internal_retire) : operation ->
            // for each token address, batch the retire operations
            let txndata_retire : external_retire list =
                List.map
                (fun (tx : internal_retire_data) : external_retire ->
                    {
                        retiring_party = (Tezos.get_self_address ()) ;
                        token_id = tx.token_id ;
                        amount = tx.amount ;
                        retiring_data = tx.retiring_data ;
                    } )
                p.txs in
            let entrypoint_retire =
                match (Tezos.get_entrypoint_opt "%retire" p.token_address : external_retire list contract option) with
                | None -> (failwith error_ADDRESS_NOT_FOUND : external_retire list contract)
                | Some c -> c in
            Tezos.transaction txndata_retire 0tez entrypoint_retire )
        param in
//    let ops_emit_retirement  =
  //      List.map
    //    (fun (p : internal_retire) : operation ->
      //      Tezos.emit "%retire" p
        //)
   // param in
    ops_retire_tokens, storage


(* =============================================================================
 * Contract Views
 * ============================================================================= *)

// contract view for balances
[@view] let view_balance_of (owner, storage : owner * storage) : nat =
    match Big_map.find_opt owner storage.ledger with
    | None -> 0n
    | Some b -> b

(* =============================================================================
 * Main Function
 * ============================================================================= *)

let main (param, storage : entrypoint * storage) : result =
    match param with
    | Internal_transfer p ->
        internal_transfer p storage
    | Internal_mint p ->
        internal_mint p storage
    | External_transfer p ->
        external_transfer p storage
    | Update_internal_operators p ->
        update_internal_operators p storage
    | Retire p ->
        retire p storage


