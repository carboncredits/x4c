(* ============================================================================
 * A Generic Testing Setup for the Carbon Token
 * ============================================================================ *)

(* ============================================================================
 * SRC
 * ============================================================================ *)

#include "../x4c-market.mligo"
let  main_market = main
type storage_market = storage 
type entrypoint_market = entrypoint 
type result_market = result

#include "../x4c-project.mligo"
let  main_fa2 = main
type storage_fa2 = storage 
type entrypoint_fa2 = entrypoint 
type result_fa2 = result

#include "../x4c-oracle.mligo"
let  main_oracle = main
type storage_oracle = storage 
type entrypoint_oracle = entrypoint 
type result_oracle = result

(* ============================================================================
 * Some Proxy Contracts
 * ============================================================================ *)

(* ============================================================================
 * Some Auxiliary Functions
 * ============================================================================ *)

let aux_tez_diff (tez1 : tez) (tez2 : tez) : nat = 
    let (nat1, nat2) = (tez1 / 1mutez, tez2 / 1mutez) in 
    abs(nat1 - nat2)

let aux_get_balance (user : address) (token_id : nat) (typed_addr_fa2 : (entrypoint_fa2, storage_fa2) typed_address) : nat = 
    let fa2_storage = Test.get_storage typed_addr_fa2 in 
    let fa2_ledger = fa2_storage.ledger in 
    match Big_map.find_opt (user, token_id) fa2_ledger with
    | None -> 0n 
    | Some b -> b

let aux_transfer_tokens (transfer_source : address) (transfer_from : address) (transfer_to : address) (token_id : nat) (transfer_amt : nat) (typed_addr_fa2 : (entrypoint_fa2, storage_fa2) typed_address) = 
    let () = Test.set_source transfer_source in 
    let transfer_entrypoint : transfer list contract = Test.to_entrypoint "transfer" typed_addr_fa2 in 
    let txn : transfer = {
        from_ = transfer_from ; 
        txs = [ { to_ = transfer_to ; token_id = token_id ; amount = transfer_amt ; } ; ] ; 
    } in 
    Test.transfer_to_contract_exn transfer_entrypoint [txn] 0tez

let aux_operator_add (owner : address) (operator : address) (token_id : nat) (operator_qty : nat) (typed_addr_fa2 : (entrypoint_fa2, storage_fa2) typed_address) = 
    let _ = Test.set_source owner in 
    let entrypoint_add_operator : update_operators contract = 
        Test.to_entrypoint "update_operators" typed_addr_fa2 in 
    let operator_data : operator_data = 
        { owner = owner ; operator = operator ; token_id = token_id ; qty = operator_qty ; } in 
    let txndata_add : update_operators = [ (Add_operator(operator_data)) ; ] in 
    Test.transfer_to_contract_exn entrypoint_add_operator txndata_add 0tez

let aux_operator_remove (owner : address) (operator : address) (token_id : nat) (operator_qty : nat) (typed_addr_fa2 : (entrypoint_fa2, storage_fa2) typed_address) = 
    let _ = Test.set_source owner in 
    let entrypoint_remove_operator : update_operators contract = 
        Test.to_entrypoint "update_operators" typed_addr_fa2 in 
    let operator_data : operator_data = 
        { owner = owner ; operator = operator ; token_id = token_id ; qty = operator_qty ; } in 
    let txndata_remove : update_operators = [ (Remove_operator(operator_data)) ; ] in 
    Test.transfer_to_contract_exn entrypoint_remove_operator txndata_remove 0tez

let aux_mint_tokens (addr_project : address) (addr_project_owner : address) (to_receive_tokens : address) 
                (token_id_to_mint : nat) (allowance_to_mint : nat) (addr_newcorp : address) 
                (typed_addr_oracle : (entrypoint_oracle, storage_oracle) typed_address) = 
    // give permissions to mint via the "approveTokens" entrypoint of the oracle contract
    let txn_approve_tokens = 
        let _ = Test.set_source addr_newcorp in 
        let txndata_approve_tokens : approve_tokens = 
            [ { token = { token_address = addr_project ; token_id = token_id_to_mint ; } ; allowance = allowance_to_mint ; } ; ] in 
        let entrypoint_approve_tokens : approve_tokens contract = 
            Test.to_entrypoint "approveTokens" typed_addr_oracle in 
        Test.transfer_to_contract_exn entrypoint_approve_tokens txndata_approve_tokens 0tez in 
    // mint tokens via the "mintTokens" entrypoint of the oracle contract
    let _ = Test.set_source addr_project_owner in 
    let txndata_mint_tokens : mint_tokens = 
        [ { owner = to_receive_tokens ; token_id = token_id_to_mint ; qty = allowance_to_mint ; } ; ] in 
    let entrypoint_mint_tokens : mint_tokens contract = 
        Test.to_entrypoint "mintTokens" typed_addr_oracle in 
    Test.transfer_to_contract_exn entrypoint_mint_tokens txndata_mint_tokens 0tez

// bury carbon 



(* ============================================================================
 * Generic Setup
 * ============================================================================ *)

let init_contracts () = 
    // generate some implicit addresses
    let (addr_alice, addr_bob, addr_operator, addr_newcorp, addr_project_owner, addr_dummy) = 
        let reset_state_unit = Test.reset_state 6n ([] : tez list) in
        (Test.nth_bootstrap_account 0, Test.nth_bootstrap_account 1, 
         Test.nth_bootstrap_account 2, Test.nth_bootstrap_account 3,
         Test.nth_bootstrap_account 4, Test.nth_bootstrap_account 5) in 
    // initiate the oracle contract 
    let _ = Test.set_source addr_newcorp in 
    let init_oracle_storage = {
        admin = addr_newcorp ;
        projects = (Big_map.empty : (project_owner, project_address) big_map) ;
        minting_permissions = (Big_map.empty : (token, nat) big_map) ;
        market_address = ("tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU" : address) ; // the canonical null address
    } in 
    let (typed_addr_oracle, _pgm_oracle, _size_oracle) = 
        Test.originate main_oracle init_oracle_storage 0tez in 
    let addr_oracle = Tezos.address (Test.to_contract typed_addr_oracle) in 
    // initiate the market contract 
    let init_market_storage = {
        tokens_for_sale = (Big_map.empty : (token_for_sale, sale_data) big_map) ;
        offers = (Big_map.empty : (token_offer, offer_data) big_map) ;
        tokens_on_auction = (Big_map.empty : (token_for_sale, auction_data) big_map) ;
        tokens_on_blind_auction = (Big_map.empty : (token_for_sale, blind_auction_data) big_map) ;
        bids_on_blind_auction = (Big_map.empty : (address * token_for_sale, chest) big_map) ;
        redeem = (Big_map.empty : (address, redeemable list) big_map) ;
        oracle_contract = Tezos.address (Test.to_contract typed_addr_oracle) ;
        approved_tokens = (Big_map.empty : (token, unit) big_map) ; 
        null_address = ("tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU" : address) ; // the canonical null address
    } in 
    let (typed_addr_market, _pgm_market, _size_market) = 
        Test.originate main_market init_market_storage 0tez in 
    let addr_market = Tezos.address (Test.to_contract typed_addr_market) in 
    // update the market address in the oracle contract
    let txn_updateMarketAddress =
        let _ = Test.set_source addr_newcorp in
        let txndata_updateMarketAddress = Tezos.address (Test.to_contract typed_addr_market) in 
        let entrypoint_updateMarketAddress : address contract = 
            Test.to_entrypoint "updateMarketAddress" typed_addr_oracle in 
        Test.transfer_to_contract_exn entrypoint_updateMarketAddress txndata_updateMarketAddress 0tez in
    // initiate a project, owned by the project owner, with three zones and no metadata
    let txn_createProject = 
        let _ = Test.set_source addr_project_owner in 
        let txndata_createProject = 
            let create_list = [
                { token_id = 0n ; token_info = (Map.empty : (string,bytes) map) ; } ; 
                { token_id = 1n ; token_info = (Map.empty : (string,bytes) map) ; } ; 
                { token_id = 2n ; token_info = (Map.empty : (string,bytes) map) ; } ; 
            ] in 
            let contract_metadata = (Big_map.empty : contract_metadata) in 
            (create_list, contract_metadata) in 
        let entrypoint_createProject : create_project contract = 
            Test.to_entrypoint "createProject" typed_addr_oracle in 
        Test.transfer_to_contract_exn entrypoint_createProject txndata_createProject 0tez in 
    // get the project address
    let addr_project = 
        let oracle_storage = Test.get_storage typed_addr_oracle in 
        match Big_map.find_opt addr_project_owner oracle_storage.projects with
        | None -> (failwith "Project Failed to be Created" : address) 
        | Some a -> a in 
    let typed_addr_project : (entrypoint_fa2, storage_fa2) typed_address = 
        Test.cast_address addr_project in 
    // assert the storage is as expected in all the contracts
    let () = 
        let oracle_storage = Test.get_storage typed_addr_oracle in 
        let new_oracle_storage = { init_oracle_storage with
            market_address = addr_market ;
            projects = (Big_map.literal [ (addr_project_owner,addr_project) ; ]) ; 
        } in 
        assert (Test.michelson_equal (Test.eval oracle_storage) (Test.eval new_oracle_storage)) in 
    let () = 
        let market_storage = Test.get_storage typed_addr_market in 
        assert (Test.michelson_equal (Test.eval market_storage) (Test.eval init_market_storage)) in 
    let () = 
        let init_project_storage = {
                owner = addr_project_owner ;
                oracle_contract = addr_oracle ;
                ledger = (Big_map.empty : (fa2_owner * fa2_token_id , fa2_amt) big_map) ;
                operators = (Big_map.empty : (fa2_owner * fa2_operator * fa2_token_id, nat) big_map) ;
                token_metadata = (Big_map.literal [
                    (0n, { token_id = 0n ; token_info = (Map.literal [] : (string, bytes) map) ; }) ;
                    (1n, { token_id = 1n ; token_info = (Map.literal [] : (string, bytes) map) ; }) ;
                    (2n, { token_id = 2n ; token_info = (Map.literal [] : (string, bytes) map) ; }) ;
                ]) ;
                metadata = (Big_map.empty : (string, bytes) big_map) ; } in 
        let project_storage = Test.get_storage typed_addr_project in 
        assert (Test.michelson_equal (Test.eval project_storage) (Test.eval init_project_storage)) in 
    // return all addresses 
    (addr_alice, addr_bob, addr_operator, addr_newcorp, addr_project_owner, addr_dummy,
     typed_addr_oracle, typed_addr_market, typed_addr_project)

// initiate contracts with an FA2 balance 
let init_contracts_with_balance (alice_bal, alice_token_id : nat * nat) (bob_bal, bob_token_id : nat * nat) = 
    // init all contracts 
    let (addr_alice, addr_bob, addr_operator, addr_newcorp, addr_project_owner, addr_dummy,
        typed_addr_oracle, typed_addr_market, typed_addr_project) = init_contracts() in 
    let addr_project = Tezos.address (Test.to_contract typed_addr_project) in 
    // mint tokens
    let txn_mint_tokens = 
        aux_mint_tokens addr_project addr_project_owner addr_alice alice_token_id 
                       alice_bal addr_newcorp typed_addr_oracle in 
    let txn_mint_tokens = 
        aux_mint_tokens addr_project addr_project_owner addr_bob bob_token_id 
                       bob_bal addr_newcorp typed_addr_oracle in
    // return all addresses 
    (addr_alice, addr_bob, addr_operator, addr_newcorp, addr_project_owner, addr_dummy,
     typed_addr_oracle, typed_addr_market, typed_addr_project)

// initiates an instance with alice, bob, and an operator
let init_fa2_contract (alice_bal : nat) (bob_bal : nat) (token_id : nat) = 
    // generate some implicit addresses
    let (addr_alice, addr_bob, addr_operator, addr_oracle, addr_dummy) = 
        let reset_state_unit = Test.reset_state 5n ([] : tez list) in
        (Test.nth_bootstrap_account 0, Test.nth_bootstrap_account 1, 
         Test.nth_bootstrap_account 2, Test.nth_bootstrap_account 3,
         Test.nth_bootstrap_account 4) in 
    // initiate contract; both alice and bob have 1000n tokens
    let (typed_addr_fa2, _pgm_fa2, _size_fa2) = 
        let init_fa2_storage = {
            owner = addr_operator ; 
            oracle_contract = addr_oracle ; // for testing purposes only
            ledger = (Big_map.literal [ ((addr_alice, token_id), alice_bal) ; ((addr_bob, token_id), bob_bal) ; ]);
            operators = (Big_map.empty : (fa2_owner * fa2_operator * fa2_token_id, nat) big_map) ; 
            token_metadata = (Big_map.empty : (fa2_token_id, token_metadata) big_map) ;
            metadata = (Big_map.empty : (string, bytes) big_map) ;
        } in
        Test.originate main_fa2 init_fa2_storage 0tez in
    // verify setup 
    let _ = 
        // alice's balance
        let alice_balance = aux_get_balance addr_alice token_id typed_addr_fa2 in 
        // bob's balance
        let bob_balance = aux_get_balance addr_bob token_id typed_addr_fa2 in 
        // test that alice_balance and bob_balance are as expected 
        assert ((alice_balance, bob_balance) = (alice_bal,bob_bal)) in 
    (addr_alice, addr_bob, addr_operator, addr_dummy, addr_oracle, typed_addr_fa2)
