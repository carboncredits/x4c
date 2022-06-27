// baker contract 
// keeps track of bakers and balances ; anyone can top up for any baker 
//  - admin is allowed to purchase and auto-retire (this will the bot)

(* =============================================================================
 * Storage
 * ============================================================================= *)


type storage = {
    // contract admin
    admin : address ; 

    // baker balances 
    baker_balances : (address, nat) big_map ; 
    outstanding_blocks : (address, nat) big_map ; // called by a bot

    // contract metadata 
    metadata : (string, bytes) big_map;
}


type result = operation list * storage 


(* =============================================================================
 * Entrypoint Type Definition
 * ============================================================================= *)

type retire_tokens = {
    retiring_party : address ; 
    token_id : nat ;
    amount : nat ;
    retiring_data : bytes ;
}
type retire = retire_tokens list 

type top_up_balance = { baker : address ; } 
type update_outstanding_blocks = { baker : address ; qty : nat ; } // 
type baker_retire = {
    baker : address ; 
    blocks_offset : nat ;
    balance_diff : nat ;
    token_contract : address ; // the carbon token address
    retire_metadata : bytes ; // for the data on retiring, incl specific blocks offset
    retire_txndata : retire ; // for the retire transaction
}

type manage_treasury = { to_ : address ; amt_ : nat ; }

type entrypoint = 
| Top_up_balance of top_up_balance 
| Update_outstanding_blocks of update_outstanding_blocks list 
| Baker_retire of baker_retire list 
| Manage_treasury of manage_treasury list 

(* =============================================================================
 * Error Codes
 * ============================================================================= *)

let error_PERMISSIONS_DENIED = 0n
let error_INSUFFICIENT_BALANCE = 1n 
let error_INSUFFICIENT_OUTSTANDING_BLOCKS = 2n 
let error_ADDRESS_NOT_FOUND = 3n

(* =============================================================================
 * Aux Functions
 * ============================================================================= *)

let update_balance (type k) (k : k) (diff : int) (ledger : (k, nat) big_map) : (k, nat) big_map = 
    let new_bal = 
        let old_bal = match Big_map.find_opt k ledger with | None -> 0n | Some b -> b in 
        if old_bal + diff < 0 then (failwith error_INSUFFICIENT_BALANCE : nat) else 
        abs(old_bal + diff) in 
    Big_map.update k (if new_bal = 0n then None else Some new_bal) ledger 

(* =============================================================================
 * Entrypoint Functions
 * ============================================================================= *)

// anyone can top up a baker's balance
let top_up_balance (p : top_up_balance) (storage : storage) : result = 
    ([] : operation list),
    { storage with baker_balances =  
        update_balance p.baker (int (Tezos.amount / 1mutez)) storage.baker_balances ; }

// periodically, the admin updates outstanding blocks 
let update_outstanding_blocks (param : update_outstanding_blocks list) (storage : storage) : result = 
    if Tezos.sender <> storage.admin then (failwith error_PERMISSIONS_DENIED : result) else 
    // add balances 
    let storage = 
        List.fold 
        (fun (s, p : storage * update_outstanding_blocks) : storage -> 
            let baker_outstanding = match Big_map.find_opt p.baker s.outstanding_blocks with | None -> 0n | Some b -> b in 
            { s with 
                outstanding_blocks = Big_map.update p.baker (Some (baker_outstanding + p.qty)) s.outstanding_blocks ; 
            } )
        param 
        storage 
        in 
    ([] : operation list), storage

// the admin can retire carbon credits for the bakers 
let baker_retire (param : baker_retire list) (storage : storage) : result = 
    // check permissions
    if Tezos.sender <> storage.admin then (failwith error_PERMISSIONS_DENIED : result) else 
    // retire the tokens 
    List.fold 
    (fun ((o, storage), p : ((operation list) * storage) * baker_retire) : ((operation list) * storage) -> 
        // updates balance internally 
        let storage = {
            storage with 
            baker_balances = update_balance p.baker (- p.balance_diff) storage.baker_balances ;
            outstanding_blocks = update_balance p.baker (- p.blocks_offset) storage.outstanding_blocks ;
        } in 
        // the retire operation 
        let op_retire = 
            let txn_entrypoint = 
                match (Tezos.get_entrypoint_opt "%retire" p.token_contract : retire contract option) with 
                | None -> (failwith error_ADDRESS_NOT_FOUND : retire contract)
                | Some c -> c in 
            Tezos.transaction p.retire_txndata 0tez txn_entrypoint in     
        // update the accumulator
        (op_retire :: o), storage)
    param 
    (([] : operation list), storage)

// the admin can manage the treasury
let manage_treasury (param : manage_treasury list) (storage : storage) : result = 
    // check permissions
    if Tezos.sender <> storage.admin then (failwith error_PERMISSIONS_DENIED : result) else 
    // disburse funds 
    (List.fold 
    (fun (o, p : operation list * manage_treasury) : operation list -> 
        let op_disburse_funds = 
            match (Tezos.get_entrypoint_opt "%main" p.to_ : unit contract option) with 
            | None -> (failwith error_ADDRESS_NOT_FOUND : operation)
            | Some c -> Tezos.transaction () (p.amt_ * 1mutez) c in 
        (op_disburse_funds :: o))
    param 
    ([] : operation list)),
    // storage
    storage


(* =============================================================================
 * Contract Views
 * ============================================================================= *)

// view baker balance
[@view] let view_baker_balance (baker, storage : address * storage) : nat = 
    match Big_map.find_opt baker storage.baker_balances with 
    | None -> 0n 
    | Some b -> b

// view outstanding blocks 
[@view] let view_outstanding_blocks (baker, storage : address * storage) : nat = 
    match Big_map.find_opt baker storage.outstanding_blocks with 
    | None -> 0n 
    | Some b -> b

(* =============================================================================
 * Main Function
 * ============================================================================= *)

let main (param, storage : entrypoint * storage) : result = 
    match param with 
    | Top_up_balance p -> 
        top_up_balance p storage 
    | Update_outstanding_blocks p -> 
        update_outstanding_blocks p storage 
    | Baker_retire p -> 
        baker_retire p storage
    | Manage_treasury p -> 
        manage_treasury p storage
