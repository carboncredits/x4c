(* ============================================================================
 * SRC: FA2 Carbon Contract 
 * ============================================================================ *)

#include "test-generic-setup.mligo"

(* ============================================================================
 * Test Transfer 
 * ============================================================================ *)

(* Test a simple transfer *)
let test_transfer = 
    // parameters 
    let alice_bal = 1000n in 
    let bob_bal   = 1000n in 
    let transfer_amt = 500n in 
    let transfer_token_id = 0n in 
    // contract setup 
    let (addr_alice, addr_bob, addr_operator, addr_dummy, addr_oracle, typed_addr_fa2) = 
        init_fa2_contract alice_bal bob_bal transfer_token_id in   
    // transfer 500n from alice to bob 
    let txn_transfer = 
        aux_transfer_tokens addr_alice addr_alice addr_bob transfer_token_id transfer_amt typed_addr_fa2 in 
    // alice's balance
    let alice_balance = aux_get_balance addr_alice transfer_token_id typed_addr_fa2 in 
    // bob's balance
    let bob_balance = aux_get_balance addr_bob transfer_token_id typed_addr_fa2 in 
    // test that alice_balance = 500n and bob_balance = 1500n 
    assert ((alice_balance,bob_balance) = (abs(alice_bal - transfer_amt),(bob_bal + transfer_amt)))

(* Make sure an empty list of transfers behaves as expected *)
let test_transfer_empty = 
    // parameters
    let alice_bal = 0n in 
    let bob_bal = 0n in 
    let transfer_token_id = 0n in 
    // contract setup 
    let (addr_alice, addr_bob, addr_operator, addr_dummy, addr_oracle, typed_addr_fa2) = 
        init_fa2_contract alice_bal bob_bal transfer_token_id in
    // call the transfer entrypoint with an empty list from alice to bob 
    let alice_source = Test.set_source addr_alice in 
    let transfer_entrypoint : transfer list contract = 
        Test.to_entrypoint "transfer" typed_addr_fa2 in 
    let txn : transfer = {
        from_ = addr_alice ; 
        txs = ([] : transfer_to list) ; 
    } in 
    let _ = Test.transfer_to_contract_exn transfer_entrypoint [txn] 0tez in 
    // query balances 
    let alice_balance = aux_get_balance addr_alice transfer_token_id typed_addr_fa2 in 
    let bob_balance = aux_get_balance addr_bob transfer_token_id typed_addr_fa2 in 
    // test that balances did not change 
    assert ((alice_balance,bob_balance) = (alice_bal,bob_bal))

let test_transfer_mutation = ()

(* ============================================================================
 * Test Update_operators Entrypoint
 * ============================================================================ *)
// add an operator and verify
let test_operator_add = 
    // parameters
    let alice_bal = 100n in 
    let bob_bal = 100n in 
    let operator_qty = 100n in 
    let operator_token_id = 0n in 
    // contract setup 
    let (addr_alice, addr_bob, addr_operator, addr_dummy, addr_oracle, typed_addr_fa2) = 
        init_fa2_contract alice_bal bob_bal operator_token_id in
    // add addr_operator as an operator 
    let txn_add_operator = 
        aux_operator_add addr_alice addr_operator operator_token_id operator_qty typed_addr_fa2 in 
    // verify addr_operator is now an operator of token with id = operator_token_id
    let operator_query = (addr_alice,addr_operator,operator_token_id) in
    let fa2_storage = Test.get_storage typed_addr_fa2 in 
    assert (Big_map.find_opt operator_query fa2_storage.operators = Some operator_qty)

let test_operator_remove = 
    // parameters
    let alice_bal = 100n in 
    let bob_bal = 100n in 
    let operator_qty = 100n in 
    let operator_token_id = 0n in 
    // contract setup 
    let (addr_alice, addr_bob, addr_operator, addr_dummy, addr_oracle, typed_addr_fa2) = 
        init_fa2_contract alice_bal bob_bal operator_token_id in
    // add addr_operator as an operator 
    let txn_add_operator = 
        aux_operator_add addr_alice addr_operator operator_token_id operator_qty typed_addr_fa2 in 
    // verify addr_operator is now an operator of token with id = 0n
    let operator_query = (addr_alice,addr_operator,operator_token_id) in
    let fa2_storage = Test.get_storage typed_addr_fa2 in 
    let _ = assert (Big_map.find_opt operator_query fa2_storage.operators = Some operator_qty) in 
    // remove addr_operator as an operator 
    let txn_remove_operator = 
        aux_operator_remove addr_alice addr_operator operator_token_id operator_qty typed_addr_fa2 in 
    // verify addr_operator is no loger an operator
    let operator_query = (addr_alice,addr_operator,operator_token_id) in
    let fa2_storage = Test.get_storage typed_addr_fa2 in 
    assert (Big_map.find_opt operator_query fa2_storage.operators = (None : nat option))

let test_operator_balance = 
    // parameters 
    let alice_bal = 100n in 
    let bob_bal = 100n in 
    let operator_token_id = 0n in 
    let operator_qty = 100n in 
    let operator_spend_qty = 50n in 
    // contract setup 
    let (addr_alice, addr_bob, addr_operator, addr_dummy, addr_oracle, typed_addr_fa2) = 
        init_fa2_contract alice_bal bob_bal operator_token_id in
    // add addr_operator as an operator 
    let txn_add_operator = 
        aux_operator_add addr_alice addr_operator operator_token_id operator_qty typed_addr_fa2 in 
    // verify addr_operator is now an operator of token with id = operator_token_id
    let operator_query = (addr_alice,addr_operator,operator_token_id) in
    let fa2_storage = Test.get_storage typed_addr_fa2 in 
    let _ = assert (Big_map.find_opt operator_query fa2_storage.operators = Some operator_qty) in 
    // the operator spends some tokens 
    let txn_operator_spend =
        aux_transfer_tokens addr_operator addr_alice addr_bob operator_token_id operator_spend_qty typed_addr_fa2 in 
    // verify the transfer executed and the operator now has the expected permissions 
    let fa2_storage = Test.get_storage typed_addr_fa2 in 
    // alice's balance = alice_bal - operator_spend_qty
    let _ = assert (Big_map.find_opt (addr_alice, operator_token_id) fa2_storage.ledger = Some (abs(alice_bal - operator_spend_qty))) in 
    // bob's balance = bob_bal + operator_spend_qty
    let _ = assert (Big_map.find_opt (addr_bob, operator_token_id) fa2_storage.ledger = Some (bob_bal + operator_spend_qty)) in 
    // addr_operator now only has permissions for operator_qty - operator_spend_qty tokens
    assert (Big_map.find_opt operator_query fa2_storage.operators = Some (abs(operator_qty - operator_spend_qty))) 

let test_operator_mutation = ()


(* ============================================================================
 * Test Balance_of Entrypoint 
 * ============================================================================ *)
// an auxiliary contract to test this entrypoint 
let get_bal (input, storage : callback_data list * nat) = 
    ([] : operation list),
    (match input with 
        | x :: xs -> x.balance 
        | [] -> 0n )

let get_bal_2 (input, storage : callback_data list * (callback_data list)) = 
    ([] : operation list),
    input

let test_get_bal = 
    let alice_bal = 10n in 
    let bob_bal = 10n in 
    let token_id_balance = 0n in 
    // 
    let (addr_alice, addr_bob, addr_operator, addr_dummy, addr_oracle, typed_addr_fa2) = 
        init_fa2_contract alice_bal bob_bal token_id_balance in
    // deploy the get_bal contract 
    let (typed_addr_get_bal, _, _) = Test.originate get_bal 0n 0tez in 
    // 
    let txn_update_get_bal = 
        let txndata_get_bal : callback_data list = [ { 
            request = { owner = addr_alice ; token_id = 0n ; } ;
            balance = 10n ; } ; ] in 
        let entrypoint_get_bal : callback_data list contract = 
            Test.to_contract typed_addr_get_bal in 
        Test.transfer_to_contract_exn entrypoint_get_bal txndata_get_bal 0tez in 
    // check balance 
    assert (alice_bal = (Test.get_storage typed_addr_get_bal))

(* returns "Running Failed" error
let test_get_balance = 
    // parameters
    let token_id_balance = 0n in 
    // init all contracts 
    let (addr_alice, addr_bob, addr_operator, addr_newcorp, addr_project_owner, addr_dummy,
     typed_addr_oracle, typed_addr_market, typed_addr_project) = init_contracts() in 
    // deploy the get_bal contract 
    let (typed_addr_get_bal, _, _) = Test.originate get_bal_2 ([] : callback_data list) 0tez in 
    // ping the balance_of entrypoint
    let txn_balance_of =
        let callback : callback_data list contract = 
            Test.to_contract typed_addr_get_bal in
        let txndata_balance_of : balance_of = {
            requests = [ { owner = addr_alice ; token_id = token_id_balance ; } ; ] ;
            callback = callback ; } in 
        let entrypoint_balance_of : balance_of contract = 
            Test.to_entrypoint "balance_of" typed_addr_project in
        Test.transfer_to_contract_exn entrypoint_balance_of txndata_balance_of 0tez in 
    // make sure that alice's balance is equal to 
    let alice_balance = aux_get_balance addr_alice token_id_balance typed_addr_fa2 in 
    let alice_balance_queried = Test.get_storage typed_addr_get_bal in 
    assert (alice_balance = alice_balance_queried) 
*)

let test_balance_mutation = ()


(* ============================================================================
 * Test Mint Entrypoint 
 * ============================================================================ *)
(* mint 100n tokens and give them to alice *) 
let test_mint_from_oracle = 
    // parameters 
    let allowance_to_mint = 100n in 
    let token_id_to_mint = 0n in 
    // init all contracts 
    let (addr_alice, addr_bob, addr_operator, addr_newcorp, addr_project_owner, addr_dummy,
     typed_addr_oracle, typed_addr_market, typed_addr_project) = init_contracts() in 
    let addr_project = Tezos.address (Test.to_contract typed_addr_project) in 
    // mint tokens
    let txn_mint_tokens = 
        aux_mint_tokens addr_project addr_project_owner addr_alice token_id_to_mint 
                       allowance_to_mint addr_newcorp typed_addr_oracle in 
    // check storage 
    let alice_balance = aux_get_balance addr_alice token_id_to_mint typed_addr_project in 
    assert (alice_balance = allowance_to_mint)

(* ensure the empty list behaves as expected *)
let test_mint_from_oracle = 
    // parameters 
    let token_id_to_mint = 0n in 
    // init all contracts 
    let (addr_alice, addr_bob, addr_operator, addr_newcorp, addr_project_owner, addr_dummy,
     typed_addr_oracle, typed_addr_market, typed_addr_project) = init_contracts() in 
    let addr_project = Tezos.address (Test.to_contract typed_addr_project) in 
    // mint tokens:
    // give permissions to mint via the "approveTokens" entrypoint of the oracle contract
    let txn_approve_tokens = 
        let _ = Test.set_source addr_newcorp in 
        let txndata_approve_tokens : approve_tokens = [] in 
        let entrypoint_approve_tokens : approve_tokens contract = 
            Test.to_entrypoint "approveTokens" typed_addr_oracle in 
        Test.transfer_to_contract_exn entrypoint_approve_tokens txndata_approve_tokens 0tez in 
    // mint tokens via the "mintTokens" entrypoint of the oracle contract
    let txn_mint_tokens = 
        let _ = Test.set_source addr_project_owner in 
        let txndata_mint_tokens : mint_tokens = [] in 
        let entrypoint_mint_tokens : mint_tokens contract = 
            Test.to_entrypoint "mintTokens" typed_addr_oracle in 
        Test.transfer_to_contract_exn entrypoint_mint_tokens txndata_mint_tokens 0tez in 
    // check storage 
    let alice_balance = aux_get_balance addr_alice token_id_to_mint typed_addr_project in 
    assert (alice_balance = 0n)


let test_mint_mutation = ()


(* ============================================================================
 * Test Burn Entrypoint 
 * ============================================================================ *)

// alice buries bury_amt number of tokens
let test_bury =
    // parameters
    let alice_bal = 1000n in 
    let token_id_to_bury = 0n in 
    let bury_amt = 500n in 
    let addr_bury = ("tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU" : address) in
    // init all contracts 
    let (addr_alice, addr_bob, addr_operator, addr_newcorp, addr_project_owner, addr_dummy,
     typed_addr_oracle, typed_addr_market, typed_addr_project) = init_contracts() in 
    let addr_project = Tezos.address (Test.to_contract typed_addr_project) in 
    // mint alice_bal tokens for alice
    let txn_mint_tokens = 
        aux_mint_tokens addr_project addr_project_owner addr_alice 
                    token_id_to_bury alice_bal addr_newcorp 
                    typed_addr_oracle in  
    // burn burn_amt in tokens
    let txn_bury_tokens = 
        let _ = Test.set_source addr_alice in
        let txndata_bury_tokens : bury_carbon = 
            [ { project_address = addr_project ; token_id = token_id_to_bury ; qty = bury_amt ; } ; ] in
        let entrypoint_bury_tokens : bury_carbon contract = 
            Test.to_entrypoint "buryCarbon" typed_addr_oracle in 
        Test.transfer_to_contract_exn entrypoint_bury_tokens txndata_bury_tokens 0tez in 
    // check balances
    let alice_balance = aux_get_balance addr_alice token_id_to_bury typed_addr_project in 
    let bury_balance = aux_get_balance addr_bury token_id_to_bury typed_addr_project in 
    assert (alice_balance = abs(alice_bal - bury_amt) && bury_balance = bury_amt)

(* Make sure an empty list of bury behaves as expected *)
let test_bury_empty = 
    // contract setup 
    let alice_bal = 1000n in 
    let token_id_to_bury = 0n in 
    let addr_bury = ("tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU" : address) in
    // init all contracts 
    let (addr_alice, addr_bob, addr_operator, addr_newcorp, addr_project_owner, addr_dummy,
     typed_addr_oracle, typed_addr_market, typed_addr_project) = init_contracts() in 
    let addr_project = Tezos.address (Test.to_contract typed_addr_project) in 
    // mint alice_bal tokens for alice
    let txn_mint_tokens = 
        aux_mint_tokens addr_project addr_project_owner addr_alice 
                    token_id_to_bury alice_bal addr_newcorp 
                    typed_addr_oracle in  
    // burn burn_amt in tokens
    let txn_bury_tokens = 
        let _ = Test.set_source addr_alice in
        let txndata_bury_tokens : bury_carbon = [] in
        let entrypoint_bury_tokens : bury_carbon contract = 
            Test.to_entrypoint "buryCarbon" typed_addr_oracle in 
        Test.transfer_to_contract_exn entrypoint_bury_tokens txndata_bury_tokens 0tez in 
    // check balances
    let alice_balance = aux_get_balance addr_alice token_id_to_bury typed_addr_project in 
    let bury_balance = aux_get_balance addr_bury token_id_to_bury typed_addr_project in 
    assert (alice_balance = alice_bal && bury_balance = 0n)


let test_burn_mutation = ()


(* ============================================================================
 * Test Metadata Entrypoint 
 * ============================================================================ *)
let test_metadata = () 

let test_metadata_empty = () 
    // Make sure the empty list behaves as expected 

let test_metadata_mutation = ()

