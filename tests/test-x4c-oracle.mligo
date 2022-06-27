(* ============================================================================
 * SRC: FA2 Carbon Contract 
 * ============================================================================ *)

#include "../x4c-oracle.mligo"
let  main_carbon = main
type storage_carbon = storage 
type entrypoint_carbon = entrypoint 
type result_carbon = result

(* ============================================================================
 * Generic Carbon Contract Setup Function
 * ============================================================================ *)

// initiates an instance with alice, bob, and an operator
let init_carbon_contract () = 
    // generate some implicit addresses
    let reset_state_unit = Test.reset_state 4n ([] : tez list) in
    let (addr_alice, addr_bob, addr_newcorp, addr_dummy) = 
        (Test.nth_bootstrap_account 0, Test.nth_bootstrap_account 1, 
         Test.nth_bootstrap_account 2, Test.nth_bootstrap_account 3) in 

    // initiate contract; both alice and bob have 1000n tokens
    let init_carbon_storage : storage_carbon = {
        admin = addr_newcorp ;
        projects = (Big_map.empty : (project_owner, project_address) big_map) ;
        minting_permissions = (Big_map.empty : (token, nat) big_map) ; 
        c4x_address = addr_newcorp ; // TODO : make this something else
    } in
    let (typed_addr_carbon, _pgm_carbon, _size_carbon) = 
        Test.originate main_carbon init_carbon_storage 0tez in
    (addr_alice, addr_bob, addr_newcorp, addr_dummy, typed_addr_carbon)

let test_verify_setup = 
    let (addr_alice, addr_bob, addr_newcorp, addr_dummy, typed_addr_carbon) = 
        init_carbon_contract () in 
    ()


(* ============================================================================
 * Create Project Tests
 * ============================================================================ *)

let test_create_project = 
    let (addr_alice, addr_bob, addr_newcorp, addr_dummy, typed_addr_carbon) = 
        init_carbon_contract () in 

    // alice will create a project with three token types
    let () = Test.set_source addr_alice in
    let alice_project_data : create_project = (
        [
            { token_id = 0n ; token_info = (Map.empty : (string, bytes) map) }; //(Map.literal [ ("first", Bytes.pack "A") ]) ) ;
            { token_id = 1n ; token_info = (Map.empty : (string, bytes) map) }; //(Map.literal [ ("first", Bytes.pack "B") ]) ) ;
            { token_id = 2n ; token_info = (Map.empty : (string, bytes) map) }; //(Map.literal [ ("first", Bytes.pack "C") ]) ) ;
        ],
            (Big_map.empty : (string, bytes) big_map)
        ) in 
    let entrypoint_create_project : create_project contract = 
        Test.to_entrypoint "createProject" typed_addr_carbon in 
    let create_project_alice = 
        Test.transfer_to_contract_exn entrypoint_create_project alice_project_data 0tez in 
    
    // verify the project got created
    let contract_storage = Test.get_storage typed_addr_carbon in 
    let current_projects = contract_storage.projects in 

    if not Big_map.mem addr_alice current_projects 
        then (failwith "NO_PROJECT_FOUND" : unit)
        else () // the test succeeded
        // (*debug mode*) else (addr_alice, addr_project_alice)


(* ============================================================================
 * Mint and Bury Carbon Tests
 * ============================================================================ *)

let test_mint_tokens = 
    let (addr_alice, addr_bob, addr_newcorp, addr_dummy, typed_addr_carbon) = 
        init_carbon_contract () in 

    // alice will create a project with three token types
    let () = Test.set_source addr_alice in
    let alice_project_data : create_project = (
        [
            { token_id = 0n ; token_info = (Map.empty : (string, bytes) map) }; //(Map.literal [ ("first", Bytes.pack "A") ]) ) ;
            { token_id = 1n ; token_info = (Map.empty : (string, bytes) map) }; //(Map.literal [ ("first", Bytes.pack "B") ]) ) ;
            { token_id = 2n ; token_info = (Map.empty : (string, bytes) map) }; //(Map.literal [ ("first", Bytes.pack "C") ]) ) ;
        ],
            (Big_map.empty : (string, bytes) big_map)
        ) in 
    let entrypoint_create_project : create_project contract = 
        Test.to_entrypoint "createProject" typed_addr_carbon in 
    let create_project_alice = 
        Test.transfer_to_contract_exn entrypoint_create_project alice_project_data 0tez in 
    
    // verify the project got created
    let contract_storage = Test.get_storage typed_addr_carbon in 
    let current_projects = contract_storage.projects in 

    let addr_project_alice : address = 
        match (Big_map.find_opt addr_alice current_projects : project_address option) with 
        | None -> (failwith "NO_PROJECT_FOUND" : address)
        | Some p -> p in

    (* TODO : When LIGO is fixed, you can get_entrypoint_opt again
    // alice will mint 100 tokens of id 0n, 1n, 2n, for bob, herself, dummy
    let txndata_mint = [
        (addr_bob,   0n, 100n) ;
        (addr_alice, 1n, 100n) ; 
        (addr_dummy, 2n, 100n) ;
    ] in 
    let entrypoint_mint : mint contract = 
        (match (Tezos.get_entrypoint_opt "%mint" addr_project_alice : mint contract option) with
        | None -> (failwith "NO_ENTRYPOINT_FOUND" : mint contract)
        | Some c -> c) in 
    let op_mint = 
        Test.transfer_to_contract_exn entrypoint_mint txndata_mint 0tez in 
    
    ()
    *)

    (addr_alice, addr_project_alice)

