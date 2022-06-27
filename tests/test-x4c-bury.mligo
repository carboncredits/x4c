(* ============================================================================
 * SRC: FA2 Carbon Contract 
 * ============================================================================ *)

#include "../x4c-oracle.mligo"
let  main_carbon = main
type storage_carbon = storage 
type entrypoint_carbon = entrypoint 
type result_carbon = result

#include "../x4c-project.mligo"
let  main_fa2 = main
type storage_fa2 = storage 
type entrypoint_fa2 = entrypoint 
type result_fa2 = result

(* ============================================================================
 * Some Proxy Contracts
 * ============================================================================ *)

type get_bal_storage = fa2_amt
type get_balance = (fa2_owner * fa2_token_id * fa2_amt) list
type get_balance_entrypoint = (fa2_owner * fa2_token_id * fa2_amt) list
type get_bal_result = (operation list) * get_bal_storage
let get_bal (input, storage : get_balance_entrypoint * get_bal_storage) : get_bal_result = 
    ([] : operation list),
    (match input with 
        | (owner,id,amt) :: xs -> amt
        | [] -> 0n
    )

(* ============================================================================
 * Generic Setup Function
 * ============================================================================ *)

// initiates an instance with alice, bob, and an operator
let init_contracts (alice_bal : nat) (bob_bal : nat) = 
    // generate some implicit addresses
    let reset_state_unit = Test.reset_state 4n ([] : tez list) in
    let (addr_alice, addr_bob, addr_operator, addr_dummy) = 
        (Test.nth_bootstrap_account 0, Test.nth_bootstrap_account 1, 
         Test.nth_bootstrap_account 2, Test.nth_bootstrap_account 3) in 

    // initiate contract; both alice and bob have 1000n tokens
    let init_fa2_storage = {
        carbon_contract = ("tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU" : address);
        fa2_ledger = ( Big_map.literal [ ((addr_alice, 0n), alice_bal) ; ((addr_bob, 0n), bob_bal) ; ] );
        operators  = ( Big_map.literal [ ((addr_operator, 0n), ()); ] ) ; 
        metadata   = ( Big_map.empty : (fa2_token_id, token_metadata) big_map ) ;
    } in
    let (typed_addr_fa2, pgm_fa2, size_fa2) = 
        Test.originate main_fa2 init_fa2_storage 0tez in
     (addr_alice, addr_bob, addr_operator, addr_dummy, typed_addr_fa2)

(* A test to make sure the setup results as expected *)
let test_verify_setup = 
    let alice_bal = 100n in 
    let bob_bal   = 100n in 
    let (addr_alice, addr_bob, addr_operator, addr_dummy, typed_addr_fa2) = 
        init_contracts alice_bal bob_bal in

    // assert the storage (balances) are what they should be 
    let (typed_addr_get_bal, pgm_get_bal, size_get_bal) = Test.originate get_bal 0n 0tez in 
    let entrypoint_balance_of : balance_of contract = (Test.to_entrypoint "balance_of" typed_addr_fa2) in
    let addr_get_bal : get_balance_entrypoint contract = (Test.to_contract typed_addr_get_bal) in
    // alice's balance
    let alice_bal_query : balance_of = ([ (addr_alice, 0n); ], addr_get_bal) in 
    let get_balance_alice = Test.transfer_to_contract_exn entrypoint_balance_of alice_bal_query 0tez in
    let alice_balance = Test.get_storage typed_addr_get_bal in 
    // bob's balance
    let bob_bal_query : balance_of = ([ (addr_bob, 0n); ], addr_get_bal) in 
    let get_balance_bob = Test.transfer_to_contract_exn entrypoint_balance_of bob_bal_query 0tez in
    let bob_balance = Test.get_storage typed_addr_get_bal in 
    
    // test that alice_balance = 500n and bob_balance = 1500n 
    (assert (alice_balance = alice_bal), assert (bob_balance = bob_bal))


(* ============================================================================
 * Test Transfer 
 * ============================================================================ *)

(* Test a simple transfer *)
(* TODO: Paramaterize this over 100ds of random values *)
let test_transfer = 
    // contract setup 
    let alice_bal = 1000n in 
    let bob_bal   = 1000n in 
    let transfer_amt = 500n in 
    let (addr_alice, addr_bob, addr_operator, addr_dummy, typed_addr_fa2) = 
        init_contracts alice_bal bob_bal in
    
    // transfer 500n from alice to bob 
    let alice_source = Test.set_source addr_alice in 
    let transfer_entrypoint = 
        ((Test.to_entrypoint "transfer" typed_addr_fa2) : transfer contract) in 
    let txn : transfer = (addr_alice , [ (addr_bob, 0n, transfer_amt); ] ) in
    let transfer_alice_to_bob = 
        Test.transfer_to_contract_exn transfer_entrypoint txn 0tez in 

    // query balances 
    let (typed_addr_get_bal, pgm_get_bal, size_get_bal) = Test.originate get_bal 0n 0tez in 
    let entrypoint_balance_of : balance_of contract = (Test.to_entrypoint "balance_of" typed_addr_fa2) in
    let addr_get_bal : get_balance_entrypoint contract = (Test.to_contract typed_addr_get_bal) in
    // alice's balance
    let alice_bal_query : balance_of = ([ (addr_alice, 0n); ], addr_get_bal) in 
    let get_balance_alice = Test.transfer_to_contract_exn entrypoint_balance_of alice_bal_query 0tez in
    let alice_balance = Test.get_storage typed_addr_get_bal in 
    // bob's balance
    let bob_bal_query : balance_of = ([ (addr_bob, 0n); ], addr_get_bal) in 
    let get_balance_bob = Test.transfer_to_contract_exn entrypoint_balance_of bob_bal_query 0tez in
    let bob_balance = Test.get_storage typed_addr_get_bal in 
    
    // test that alice_balance = 500n and bob_balance = 1500n 
    (assert (alice_balance = abs(alice_bal - transfer_amt)), assert (bob_balance = (bob_bal + transfer_amt)))


(* Make sure an empty list of transfers behaves as expected *)
let test_transfer_empty = 
    // contract setup 
    let alice_bal = 0n in 
    let bob_bal = 0n in 
    let (addr_alice, addr_bob, addr_operator, addr_dummy, typed_addr_fa2) = 
        init_contracts alice_bal bob_bal in
    
    // call the transfer entrypoint with an empty list from alice to bob 
    let alice_source = Test.set_source addr_alice in 
    let transfer_entrypoint = 
        ((Test.to_entrypoint "transfer" typed_addr_fa2) : transfer contract) in 
    let txn : transfer = (addr_alice , ([] : (fa2_to * fa2_token_id * fa2_amt) list) ) in
    let transfer_alice_to_bob = 
        Test.transfer_to_contract_exn transfer_entrypoint txn 0tez in 

    // query balances 
    let (typed_addr_get_bal, pgm_get_bal, size_get_bal) = Test.originate get_bal 0n 0tez in 
    let entrypoint_balance_of : balance_of contract = (Test.to_entrypoint "balance_of" typed_addr_fa2) in
    let addr_get_bal : get_balance_entrypoint contract = (Test.to_contract typed_addr_get_bal) in
    // alice's balance
    let alice_bal_query : balance_of = ([ (addr_alice, 0n); ], addr_get_bal) in 
    let get_balance_alice = Test.transfer_to_contract_exn entrypoint_balance_of alice_bal_query 0tez in
    let alice_balance = Test.get_storage typed_addr_get_bal in 
    // bob's balance
    let bob_bal_query : balance_of = ([ (addr_bob, 0n); ], addr_get_bal) in 
    let get_balance_bob = Test.transfer_to_contract_exn entrypoint_balance_of bob_bal_query 0tez in
    let bob_balance = Test.get_storage typed_addr_get_bal in 
    
    // test that alice_balance = 500n and bob_balance = 1500n 
    (assert (alice_balance = alice_bal), assert (bob_balance = bob_bal))


let test_transfer_mutation = ()
