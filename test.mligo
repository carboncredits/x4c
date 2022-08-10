(* ============================================================================
 * Import Contracts
 * ============================================================================ *)

#include "fa2.mligo"
let  main_fa2 = main
type storage_fa2 = storage
type entrypoint_fa2 = entrypoint
type result_fa2 = result
type owner_fa2 = owner
type operator_fa2 = operator

#include "custodian.mligo"
let  main_custodian = main
type storage_custodian = storage
type entrypoint_custodian = entrypoint
type result_custodian = result
type owner_custodian = owner
type operator_custodian = operator

(* ============================================================================
 * Aux Functions
 * ============================================================================ *)

let init_contracts () =
    // generate some implicit addresses
    let (addr_alice, addr_bob, addr_operator, addr_admin, addr_dummy) =
        let _reset_state_unit = Test.reset_state 6n ([] : tez list) in
        (Test.nth_bootstrap_account 0, Test.nth_bootstrap_account 1,
         Test.nth_bootstrap_account 2, Test.nth_bootstrap_account 3,
         Test.nth_bootstrap_account 4) in

    // initiate the contracts
    let _ = Test.set_source addr_admin in

    // initiate the oracle contract
    let init_custodian_storage = {
        custodian = addr_admin ;
        ledger = (Big_map.empty : (owner_custodian, qty) big_map) ;
        operators = (Set.empty : operator_custodian set) ;
        external_ledger = (Big_map.empty : (token, nat) big_map) ;
        metadata = (Big_map.empty : (string, bytes) big_map) ;
    } in
    let (addr_custodian, _pgm_custodian, _size_custodian) =
        Test.originate_from_file "custodian.mligo" "main" [ "view_balance_of" ; ] (Test.compile_value init_custodian_storage) 0tez in
    let typed_addr_custodian = (Test.cast_address addr_custodian : (entrypoint_custodian, storage_custodian) typed_address) in

    // initiate the fa2 contract
    let init_fa2_storage = {
        oracle = addr_admin ;
        ledger = (Big_map.empty : (owner_fa2, qty) big_map) ;
        operators = (Set.empty : operator_fa2 set) ;
        token_metadata = (Big_map.empty : (token_id, token_metadata) big_map) ;
        metadata = (Big_map.empty : (string, bytes) big_map) ;
        is_active = true ;
    } in
    let (addr_fa2, _pgm_fa2, _size_fa2) =
        Test.originate_from_file "fa2.mligo" "main" [ "view_balance_of" ; "view_get_metadata" ; ] (Test.compile_value init_fa2_storage) 0tez in
    let typed_addr_fa2 = (Test.cast_address addr_fa2 : (entrypoint_fa2, storage_fa2) typed_address) in

    // return all addresses
    (addr_alice, addr_bob, addr_operator, addr_admin, addr_dummy,
     typed_addr_custodian, addr_custodian,
     typed_addr_fa2, addr_fa2)


(* ============================================================================
 * Tests
 * ============================================================================ *)

let test = 
    // initiate contracts 
    let (addr_alice, _addr_bob, addr_operator, addr_admin, _addr_dummy,
     typed_addr_custodian, addr_custodian, typed_addr_fa2, addr_fa2) = init_contracts () in 

    // add token id = 0n so it can be minted 
    let _op_add_token_id = 
        let _ = Test.set_source addr_admin in 
        let txndata_add_token_id : token_metadata list = 
            [ { token_id = 0n ; token_info = (Map.empty : (string, bytes) map) ; } ; ] in 
        let entrypoint_add_token_id : token_metadata list contract = 
            Test.to_entrypoint "add_token_id" typed_addr_fa2 in 
        Test.transfer_to_contract_exn entrypoint_add_token_id txndata_add_token_id 0tez in 

    // mint tokens for the custodian 
    let _op_mint_tokens = 
        let _ = Test.set_source addr_admin in 
        let txndata_mint_tokens : mint = [ 
            { owner = addr_custodian ; token_id = 0n ; qty = 1_000_000n ; } 
        ] in 
        let entrypoint_mint_tokens : mint contract = 
            Test.to_entrypoint "mint" typed_addr_fa2 in  
        Test.transfer_to_contract_exn entrypoint_mint_tokens txndata_mint_tokens 0tez in 

    // the custodian manages those tokens 
    let _op_internal_mint = 
        let _ = Test.set_source addr_admin in 
        let txndata_internal_mint : internal_mint list = [
            { token_id = 0n ; token_address = addr_fa2 ; } ;
        ] in 
        let entrypoint_internal_mint : internal_mint list contract = 
            Test.to_entrypoint "internal_mint" typed_addr_custodian in 
        Test.transfer_to_contract_exn entrypoint_internal_mint txndata_internal_mint 0tez in 

    // custodian sends tokens around 
    let _op_internal_transfer = 
        let _ = Test.set_source addr_admin in 
        let txndata_internal_transfer : internal_transfer list = 
            let txs = [ { to_ = (Bytes.pack "alice") ; token_id = 0n ; amount = 500_000n } ; ] in 
            [ { from_ = (Bytes.pack "self") ; token_address = addr_fa2 ; txs = txs ; } ; ] in 
        let entrypoint_internal_transfer : internal_transfer list contract = 
            Test.to_entrypoint "internal_transfer" typed_addr_custodian in 
        Test.transfer_to_contract_exn entrypoint_internal_transfer txndata_internal_transfer 0tez in 

    // custodian designates an operator for internal_transfer 
    let _op_add_operator = 
        let _ = Test.set_source addr_admin in 
        let txndata_add_operator : update_internal_operators = 
            let operator_data = { token_owner = (Bytes.pack "self") ; token_operator = addr_operator ; token_id = 0n ; } in 
            [ Add_operator(operator_data) ; ] in 
        let entrypoint_add_operator : update_internal_operators contract = 
            Test.to_entrypoint "update_internal_operators" typed_addr_custodian in 
        Test.transfer_to_contract_exn entrypoint_add_operator txndata_add_operator 0tez in 

    // operator executes an internal transfer to bob
    let _op_operator_transfer = 
        let _ = Test.set_source addr_operator in 
        let txndata_operator_transfer : internal_transfer list = 
            let txs = [ { to_ = (Bytes.pack "bob") ; token_id = 0n ; amount = 500_000n } ; ] in 
            [ { from_ = (Bytes.pack "self") ; token_address = addr_fa2 ; txs = txs ; } ; ] in 
        let entrypoint_operator_transfer : internal_transfer list contract = 
            Test.to_entrypoint "internal_transfer" typed_addr_custodian in 
        Test.transfer_to_contract_exn entrypoint_operator_transfer txndata_operator_transfer 0tez in 

    // custodian sends tokens from bob back to itself 
    let _op_internal_transfer_2 = 
        let _ = Test.set_source addr_admin in 
        let txndata_internal_transfer : internal_transfer list = 
            let txs = [ { to_ = (Bytes.pack "self") ; token_id = 0n ; amount = 500_000n } ; ] in 
            [ { from_ = (Bytes.pack "bob") ; token_address = addr_fa2 ; txs = txs ; } ; ] in 
        let entrypoint_internal_transfer : internal_transfer list contract = 
            Test.to_entrypoint "internal_transfer" typed_addr_custodian in 
        Test.transfer_to_contract_exn entrypoint_internal_transfer txndata_internal_transfer 0tez in 

    // custodian removes operator
    let _op_remove_operator = 
        let _ = Test.set_source addr_admin in 
        let txndata_remove_operator : update_internal_operators = 
            let operator_data = { token_owner = (Bytes.pack "self") ; token_operator = addr_operator ; token_id = 0n ; } in 
            [ Remove_operator(operator_data) ; ] in 
        let entrypoint_remove_operator : update_internal_operators contract = 
            Test.to_entrypoint "update_internal_operators" typed_addr_custodian in 
        Test.transfer_to_contract_exn entrypoint_remove_operator txndata_remove_operator 0tez in 

    // custodian externally transfers tokens from Alice and Self to Alice's address 
    let _op_external_transfer = 
        let _ = Test.set_source addr_admin in 
        let txndata_external_transfer : external_transfer list = 
            let txs_1 = [ { to_ = addr_alice ; token_id = 0n ; amount = 300_000n } ; ] in 
            let txs_2 = [ { to_ = addr_alice ; token_id = 0n ; amount = 200_000n } ; ] in 
            let txn_batch : external_transfer_batch list = [
                { from_ = (Bytes.pack "self")  ; txs = txs_1 ; } ;
                { from_ = (Bytes.pack "alice") ; txs = txs_2 ; } ;
                { from_ = (Bytes.pack "self")  ; txs = txs_2 ; } ;
                { from_ = (Bytes.pack "alice") ; txs = txs_1 ; } ;
            ] in
            [ { token_address = addr_fa2 ; txn_batch = txn_batch ; } ; ] in
        let entrypoint_external_transfer : external_transfer list contract =
            Test.to_entrypoint "external_transfer" typed_addr_custodian in
        Test.transfer_to_contract_exn entrypoint_external_transfer txndata_external_transfer 0tez in

    // alice transfers back to custodian
    let _op_alice_transfer_to_custodian =
        let _ = Test.set_source addr_alice in
        let txndata_transfer : transfer list =
            let txs : transfer_to list = [ { to_ = addr_custodian ; token_id = 0n ; amount = 1_000_000n ; } ; ] in
            [ { from_ = addr_alice ; txs = txs ; } ; ] in
        let entrypoint_transfer : transfer list contract =
            Test.to_entrypoint "transfer" typed_addr_fa2 in
        Test.transfer_to_contract_exn entrypoint_transfer txndata_transfer 0tez in

    // the custodian manages those tokens
    let _op_internal_mint =
        let _ = Test.set_source addr_admin in
        let txndata_internal_mint : internal_mint list = [
            { token_id = 0n ; token_address = addr_fa2 ; } ;
        ] in
        let entrypoint_internal_mint : internal_mint list contract =
            Test.to_entrypoint "internal_mint" typed_addr_custodian in
        Test.transfer_to_contract_exn entrypoint_internal_mint txndata_internal_mint 0tez in

    // the custodian retires their tokens
    let _op_retire =
        let _ = Test.set_source addr_admin in
        let txndata_retire : internal_retire list =
            let txs = [ {
                retiring_party_kyc = (Bytes.pack "self") ;
                token_id = 0n ;
                amount = 500_000n ;
                retiring_data = (Bytes.pack "this is for baker emissions") ;
            } ; ] in
            [ { token_address = addr_fa2 ; txs = txs ; } ] in
        let entrypoint_internal_retire : internal_retire list contract =
            Test.to_entrypoint "retire" typed_addr_custodian in
        Test.transfer_to_contract_exn entrypoint_internal_retire txndata_retire 0tez in

    // custodian sends tokens around
    let _op_internal_transfer =
        let _ = Test.set_source addr_admin in
        let txndata_internal_transfer : internal_transfer list =
            let txs = [ { to_ = (Bytes.pack "alice") ; token_id = 0n ; amount = 500_000n } ; ] in
            [ { from_ = (Bytes.pack "self") ; token_address = addr_fa2 ; txs = txs ; } ; ] in
        let entrypoint_internal_transfer : internal_transfer list contract =
            Test.to_entrypoint "internal_transfer" typed_addr_custodian in
        Test.transfer_to_contract_exn entrypoint_internal_transfer txndata_internal_transfer 0tez in

    // custodian externally transfers tokens from Alice and Self to Alice's address
    let _op_external_transfer =
        let _ = Test.set_source addr_admin in
        let txndata_external_transfer : external_transfer list =
            let txs = [ { to_ = addr_alice ; token_id = 0n ; amount = 500_000n } ; ] in
            let txn_batch : external_transfer_batch list =
                [ { from_ = (Bytes.pack "alice") ; txs = txs ; } ; ] in
            [ { token_address = addr_fa2 ; txn_batch = txn_batch ; } ; ] in
        let entrypoint_external_transfer : external_transfer list contract =
            Test.to_entrypoint "external_transfer" typed_addr_custodian in
        Test.transfer_to_contract_exn entrypoint_external_transfer txndata_external_transfer 0tez in

    // alice retires her tokens
    let _op_alice_retire =
        let _ = Test.set_source addr_alice in
        let txndata_alice_retire : retire_tokens list = [ {
            retiring_party = addr_alice ;
            token_id = 0n ;
            amount = 500_000n ;
            retiring_data = (Bytes.pack "for private emissions") ; } ; ] in
        let entrypoint_alice_retire : retire_tokens list contract =
            Test.to_entrypoint "retire" typed_addr_fa2 in
        Test.transfer_to_contract_exn entrypoint_alice_retire txndata_alice_retire 0tez in

    ()
    //(addr_alice, addr_custodian, (Bytes.pack "self"), (Test.get_storage typed_addr_fa2),
    //(Test.get_storage typed_addr_custodian))
