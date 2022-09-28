#include "../src/fa2.mligo"
type owner_fa2 = owner
type operator_fa2 = operator
type storage_fa2 = storage
type entrypoint_fa2 = entrypoint

#include "../src/custodian.mligo"
type storage_custodian = storage
type entrypoint_custodian = entrypoint
type result_custodian = result
type owner_custodian = owner
type operator_custodian = operator

type test_fa2 = {
	owner: address;
	contract: (entrypoint_fa2, storage_fa2) typed_address;
	contract_address: address;
}

let fa2_bootstrap(accounts_needed: nat): test_fa2 =
	let fa2_owner =
		let _ : unit = Test.reset_state accounts_needed [] in
			Test.nth_bootstrap_account 0 in

	let _ : unit = Test.set_source fa2_owner in

	let init_fa2_storage = {
		oracle = fa2_owner ;
		ledger = (Big_map.empty : (owner_fa2, nat) big_map) ;
		operators = (Set.empty : operator_fa2 set) ;
		token_metadata = (Big_map.empty : (token_id, token_metadata) big_map) ;
		metadata = (Big_map.empty : (string, bytes) big_map) ;
	} in
	let (addr_fa2, _pgm_fa2, _size_fa2) =
		Test.originate_from_file "../src/fa2.mligo" "main" [ "view_balance_of" ; "view_get_metadata" ; ] (Test.compile_value init_fa2_storage) 0tez in

	let fa2_contract : (entrypoint_fa2, storage_fa2) typed_address = Test.cast_address addr_fa2 in

	{owner = fa2_owner; contract = fa2_contract; contract_address = addr_fa2; }


let fa2_add_token (test_fa2: test_fa2) (token_id: nat) : test_exec_result =
	let _ : unit = Test.set_source test_fa2.owner in
	let txndata_add_token_id : token_metadata list =
		[ { token_id = token_id ; token_info = (Map.empty : (string, bytes) map) ; } ; ] in
	let entrypoint_add_token_id : token_metadata list contract =
		Test.to_entrypoint "add_token_id" test_fa2.contract in
	Test.transfer_to_contract entrypoint_add_token_id txndata_add_token_id 0tez


let fa2_mint_token (test_fa2: test_fa2) (token_id: nat) (owner: address) (count: nat) : test_exec_result =
	let _ : unit = Test.set_source test_fa2.owner in
	let txndata_mint_tokens : mint = [
		{ owner = owner ; token_id = token_id ; qty = count ; }
	] in
	let entrypoint_mint_tokens : mint contract =
		Test.to_entrypoint "mint" test_fa2.contract in
	Test.transfer_to_contract entrypoint_mint_tokens txndata_mint_tokens 0tez


type test_custodian = {
		owner: address;
		contract: (entrypoint_custodian, storage_custodian) typed_address;
		contract_address: address;
	}


let custodian_bootstrap (): test_custodian =
	let custodian_owner = Test.nth_bootstrap_account 1 in
	let _ : unit = Test.set_source custodian_owner in

	let init_custodian_storage = {
		custodian = custodian_owner;
		ledger = (Big_map.empty : (owner_custodian, nat) big_map);
		external_ledger = (Big_map.empty : (token, nat) big_map);
		operators = (Set.empty : operator_custodian set);
		metadata = (Big_map.empty : (string, bytes) big_map);
	} in
	let (addr_custodian, _pgm_custodian, _size_custodian) =
		Test.originate_from_file "../src/custodian.mligo" "main" [ "view_balance_of" ; ] (Test.compile_value init_custodian_storage) 0tez in
	let typed_addr_custodian = (Test.cast_address addr_custodian : (entrypoint_custodian, storage_custodian) typed_address) in

	({owner = custodian_owner; contract = typed_addr_custodian; contract_address = addr_custodian; })


let custodian_internal_mint (test_custodian: test_custodian) (test_fa2: test_fa2) (token_id: nat) : test_exec_result =
	let _ : unit = Test.set_source test_custodian.owner in
	let txndata_internal_mint : internal_mint list = [
		{ token_id = token_id ; token_address = test_fa2.contract_address ; } ;
	] in
	let entrypoint_internal_mint : internal_mint list contract =
		Test.to_entrypoint "internal_mint" test_custodian.contract in
	Test.transfer_to_contract entrypoint_internal_mint txndata_internal_mint 0tez


let custodian_retire (test_custodian: test_custodian) (test_fa2: test_fa2) (retire_data: internal_retire_data) : test_exec_result =
	let _ : unit = Test.set_source test_custodian.owner in
	let txndata_retire : internal_retire list =
		let txs = [ retire_data ; ] in
		[ { token_address = test_fa2.contract_address ; txs = txs ; } ] in
	let entrypoint_internal_retire : internal_retire list contract =
		Test.to_entrypoint "retire" test_custodian.contract in
	Test.transfer_to_contract entrypoint_internal_retire txndata_retire 0tez


let custodian_add_operator (test_custodian: test_custodian) (operator_data: operator_custodian) : test_exec_result =
	let _ : unit = Test.set_source test_custodian.owner in
	let txndata_add_operator : update_internal_operators =
		[ Add_operator(operator_data) ; ] in
	let entrypoint_add_operator : update_internal_operators contract =
		Test.to_entrypoint "update_internal_operators" test_custodian.contract in
	Test.transfer_to_contract entrypoint_add_operator txndata_add_operator 0tez


let custodian_remove_operator (test_custodian: test_custodian) (operator_data: operator_custodian) : test_exec_result =
	let _ : unit = Test.set_source test_custodian.owner in
	let txndata_add_operator : update_internal_operators =
		[ Remove_operator(operator_data) ; ] in
	let entrypoint_add_operator : update_internal_operators contract =
		Test.to_entrypoint "update_internal_operators" test_custodian.contract in
	Test.transfer_to_contract entrypoint_add_operator txndata_add_operator 0tez

let custodian_internal_transfer (test_custodian: test_custodian) (from: bytes) (to: bytes) (token: token) (amount: nat) : test_exec_result =
	let _ : unit = Test.set_source test_custodian.owner in
    let txndata_internal_transfer : internal_transfer list =
        let txs = [ { to_ = to ; token_id = token.token_id ; amount = amount } ; ] in
        [ { from_ = from ; token_address = token.token_address ; txs = txs ; } ; ] in
    let entrypoint_internal_transfer : internal_transfer list contract =
        Test.to_entrypoint "internal_transfer" test_custodian.contract in
    Test.transfer_to_contract entrypoint_internal_transfer txndata_internal_transfer 0tez
