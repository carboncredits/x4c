(* A testing framework for c4dex.mligo *)

(* ============================================================================
 * Import the Generic Testing Framework
 * ============================================================================ *)

#include "test-generic-setup.mligo"

(* ============================================================================
 * Some Proxy Contracts
 * ============================================================================ *)


(* ============================================================================
 * ForSale Tests
 * ============================================================================ *)

let test_for_sale =
    // parameters 
    let (alice_bal, alice_token_id) = (100n, 0n) in 
    let (bob_bal, bob_token_id) = (0n, 0n) in 
    let price = 100n in 
    // init all contracts 
    let (addr_alice, addr_bob, addr_operator, addr_newcorp, addr_project_owner, addr_dummy,
        typed_addr_oracle, typed_addr_market, typed_addr_project) = 
        init_contracts_with_balance (alice_bal, alice_token_id) (bob_bal, bob_token_id) in 
    let addr_project = Tezos.address (Test.to_contract typed_addr_project) in 
    // define the token to be sold and sale data 
    let token = {owner=addr_alice; token_address=addr_project; token_id=alice_token_id; qty=alice_bal; batch_number=0n ;} in 
    let data = {price=price;} in 
    // a token holder posts some tokens for sale 
    let txn_post_for_sale = 
        let _ = Test.set_source addr_alice in 
        let txndata_post_for_sale : for_sale = PostForSale((token,data)) in 
        let entrypoint_post_for_sale : for_sale contract = 
            Test.to_entrypoint "forSale" typed_addr_market in 
        Test.transfer_to_contract_exn entrypoint_post_for_sale txndata_post_for_sale 0tez in 
    // verify memory is as expected 
    let _ = 
        let _ = Test.set_source addr_alice in 
        let market_storage = Test.get_storage typed_addr_market in 
        assert(match Big_map.find_opt token market_storage.tokens_for_sale with 
        | None -> false 
        | Some d -> d = data) in 
    // unpost for sale 
    let txn_unpost_for_sale = 
        let txndata_unpost_for_sale : for_sale = UnpostForSale(token) in 
        let entrypoint_unpost_for_sale : for_sale contract = 
            Test.to_entrypoint "forSale" typed_addr_market in 
        Test.transfer_to_contract_exn entrypoint_unpost_for_sale txndata_unpost_for_sale 0tez in 
    // verify memory is as expected 
    let _ = 
        let market_storage = Test.get_storage typed_addr_market in 
        assert(match Big_map.find_opt token market_storage.tokens_for_sale with 
        | None -> true 
        | Some _ -> false) in
    // repost for sale 
    let txn_repost_for_sale = 
        let _ = Test.set_source addr_alice in 
        let txndata_repost_for_sale : for_sale = PostForSale((token,data)) in 
        let entrypoint_repost_for_sale : for_sale contract = 
            Test.to_entrypoint "forSale" typed_addr_market in 
        Test.transfer_to_contract_exn entrypoint_repost_for_sale txndata_repost_for_sale 0tez in 
    // verify memory is as expected 
    let _ = 
        let market_storage = Test.get_storage typed_addr_market in 
        assert(match Big_map.find_opt token market_storage.tokens_for_sale with 
        | None -> false 
        | Some d -> d = data) in 
    // for later
    let alice_tez_init = Test.get_balance addr_alice in 
    // buy for sale
    let txn_buy_for_sale = 
        let _ = Test.set_source addr_bob in 
        let txndata_buy_for_sale : for_sale = BuyForSale(token) in 
        let entrypoint_buy_for_sale : for_sale contract = 
            Test.to_entrypoint "forSale" typed_addr_market in 
        Test.transfer_to_contract_exn entrypoint_buy_for_sale txndata_buy_for_sale (price * 1mutez) in 
    // get updated balance
    let alice_tez_now = Test.get_balance addr_alice in 
    // verify memory is all as expected 
    let _ = 
        let market_storage = Test.get_storage typed_addr_market in 
        assert(match Big_map.find_opt token market_storage.tokens_for_sale with 
        | None -> true 
        | Some _ -> false) in 
    // verify balances
    let _ = 
    assert(
        0n        = aux_get_balance addr_alice alice_token_id typed_addr_project && 
        alice_bal = aux_get_balance addr_bob alice_token_id typed_addr_project) 
    in  
        price, aux_tez_diff alice_tez_init alice_tez_now // TODO : why is this off?

let test_forsale_collision = ()


(* ============================================================================
 * Auction Tests
 * ============================================================================ *)

let test_auction = 
    // parameters 
    let (alice_bal, alice_token_id) = (100n, 0n) in 
    let (bob_bal, bob_token_id) = (0n, 0n) in 
    let price = 100n in 
    // init all contracts 
    let (addr_alice, addr_bob, addr_operator, addr_newcorp, addr_project_owner, addr_dummy,
        typed_addr_oracle, typed_addr_market, typed_addr_project) = 
        init_contracts_with_balance (alice_bal, alice_token_id) (bob_bal, bob_token_id) in 
    let addr_project = Tezos.address (Test.to_contract typed_addr_project) in 
    // define the token to be auctioned and auction data 
    let token = {owner=addr_alice; token_address=addr_project; token_id=alice_token_id; qty=alice_bal; batch_number=0n ;} in 
    let data = {leader=addr_alice; leading_bid = 0n; deadline=("2022-01-01t10:10:10Z" : timestamp); reserve_price=100n;} in 
    // initiate the auction 
    // verify the memory
    // bid on the auction 
    // verify the memory
    // finish the auction
    // verify the memory
    // redeem 
    // verify the memory
    ()

(* ============================================================================
 * BlindAuction Tests
 * ============================================================================ *)

let test_blind_auction = () 
    // initiate the auction 
    // verify the memory
    // bid on the auction 
    // verify the memory
    // finish the auction
    // verify the memory
    // redeem
    // verify the memory

(* ============================================================================
 * Offer Tests
 * ============================================================================ *)

let test_offer = () 
    // make an offer 
    // verify the memory
    // retract the offer
    // verify the memory
    // make the offer again 
    // verify the memory
    // accept the offer 
    // verify the memory
    // redeem
    // verify the memory

(* ============================================================================
 * Redeem Tests
 * ============================================================================ *)

let test_redeem = () 
    // this should test multiple redeems all at once 

(* ============================================================================
 * OracleApproveTokens Tests
 * ============================================================================ *)

let test_oracle_approve_tokens = ()
    // approve tokens and make sure it works how you expect 