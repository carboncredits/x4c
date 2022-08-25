#import "./assert.mligo" "Assert"
#include "../fa2.mligo"
type storage_fa2 = storage
type entrypoint_fa2 = entrypoint
type owner_fa2 = owner
type operator_fa2 = operator

let bootstrap_fa2 () =
	let (fa2_owner) =
		let _reset_state_unit = Test.reset_state 6n ([] : tez list) in
			(Test.nth_bootstrap_account 0) in

	let _ = Test.set_source fa2_owner in

	let init_fa2_storage = {
		oracle = fa2_owner ;
		ledger = (Big_map.empty : (owner_fa2, nat) big_map) ;
		operators = (Set.empty : operator_fa2 set) ;
		token_metadata = (Big_map.empty : (token_id, token_metadata) big_map) ;
		metadata = (Big_map.empty : (string, bytes) big_map) ;
	} in
	let (addr_fa2, _pgm_fa2, _size_fa2) =
		Test.originate_from_file "fa2.mligo" "main" [ "view_balance_of" ; "view_get_metadata" ; ] (Test.compile_value init_fa2_storage) 0tez in
	let typed_addr_fa2 = (Test.cast_address addr_fa2 : (entrypoint_fa2, storage_fa2) typed_address) in

	// return
	(fa2_owner, typed_addr_fa2)


let test_add_token_and_mint =
	let (fa2_owner, fa2_contract) = bootstrap_fa2() in
	let _ = Test.set_source fa2_owner in

	let _op_add_token_id =
		let txndata_add_token_id : token_metadata list =
			[ { token_id = 0n ; token_info = (Map.empty : (string, bytes) map) ; } ; ] in
		let entrypoint_add_token_id : token_metadata list contract =
			Test.to_entrypoint "add_token_id" fa2_contract in
		Test.transfer_to_contract_exn entrypoint_add_token_id txndata_add_token_id 0tez in

	let _op_mint_tokens =
		let txndata_mint_tokens : mint = [
			{ owner = fa2_owner ; token_id = 0n ; qty = 1_000_000n ; }
		] in
		let entrypoint_mint_tokens : mint contract =
			Test.to_entrypoint "mint" fa2_contract in

		let res = Test.transfer_to_contract entrypoint_mint_tokens txndata_mint_tokens 0tez in

		Assert.tx_success(res) in ()


let test_mint_without_add_fails =
	let (fa2_owner, fa2_contract) = bootstrap_fa2() in
	let _ = Test.set_source fa2_owner in

	let _op_mint_tokens =
		let txndata_mint_tokens : mint = [
			{ owner = fa2_owner ; token_id = 0n ; qty = 1_000_000n ; }
		] in
		let entrypoint_mint_tokens : mint contract =
			Test.to_entrypoint "mint" fa2_contract in

		let res = Test.transfer_to_contract entrypoint_mint_tokens txndata_mint_tokens 0tez in

		Assert.failure_code res error_TOKEN_UNDEFINED in ()


let test_add_existing_token_id_fails =
	let (fa2_owner, fa2_contract) = bootstrap_fa2() in
	let _ = Test.set_source fa2_owner in

	let _op_add_token_id =
		let txndata_add_token_id : token_metadata list =
			[ { token_id = 0n ; token_info = (Map.empty : (string, bytes) map) ; } ; ] in
		let entrypoint_add_token_id : token_metadata list contract =
			Test.to_entrypoint "add_token_id" fa2_contract in
		Test.transfer_to_contract_exn entrypoint_add_token_id txndata_add_token_id 0tez in

	let _op_add_token_id_again =
		let txndata_add_token_id : token_metadata list =
			[ { token_id = 0n ; token_info = (Map.empty : (string, bytes) map) ; } ; ] in
		let entrypoint_add_token_id : token_metadata list contract =
			Test.to_entrypoint "add_token_id" fa2_contract in
		let res = Test.transfer_to_contract entrypoint_add_token_id txndata_add_token_id 0tez in

		Assert.failure_code res error_ID_ALREADY_IN_USE in ()


let test_non_oracle_add_token_fails =
	let (_, fa2_contract) = bootstrap_fa2() in
	let other_wallet = Test.nth_bootstrap_account 1 in
	let _ = Test.set_source other_wallet in

	let _op_add_token_id =
		let txndata_add_token_id : token_metadata list =
			[ { token_id = 0n ; token_info = (Map.empty : (string, bytes) map) ; } ; ] in
		let entrypoint_add_token_id : token_metadata list contract =
			Test.to_entrypoint "add_token_id" fa2_contract in
		let res = Test.transfer_to_contract entrypoint_add_token_id txndata_add_token_id 0tez in

		Assert.failure_code res error_PERMISSIONS_DENIED in ()


let test_non_oracle_mint_fails =
	let (fa2_owner, fa2_contract) = bootstrap_fa2() in

	let _op_add_token_id =
		let _ = Test.set_source fa2_owner in
		let txndata_add_token_id : token_metadata list =
			[ { token_id = 0n ; token_info = (Map.empty : (string, bytes) map) ; } ; ] in
		let entrypoint_add_token_id : token_metadata list contract =
			Test.to_entrypoint "add_token_id" fa2_contract in
		Test.transfer_to_contract_exn entrypoint_add_token_id txndata_add_token_id 0tez in

	let _op_mint_tokens =
		let other_wallet = Test.nth_bootstrap_account 1 in
		let _ = Test.set_source other_wallet in
		let txndata_mint_tokens : mint = [
			{ owner = fa2_owner ; token_id = 0n ; qty = 1_000_000n ; }
		] in
		let entrypoint_mint_tokens : mint contract =
			Test.to_entrypoint "mint" fa2_contract in

		let res = Test.transfer_to_contract entrypoint_mint_tokens txndata_mint_tokens 0tez in

		Assert.failure_code res error_PERMISSIONS_DENIED in ()


let test_update_oracle =
	let (fa2_owner, fa2_contract) = bootstrap_fa2() in
	let other_wallet = Test.nth_bootstrap_account 1 in
	let _ = Test.set_source fa2_owner in

	let current_state = Test.get_storage fa2_contract in
		let _ = assert (current_state.oracle = fa2_owner) in

	let _update_operator =
		let txndata : update_oracle = { new_oracle = other_wallet; } in
		let entrypoint : update_oracle contract =
			Test.to_entrypoint "update_oracle" fa2_contract in
		let res = Test.transfer_to_contract entrypoint txndata 0tez in

		Assert.tx_success(res) in

	let updated_state = Test.get_storage fa2_contract in
		let _ = assert (updated_state.oracle = other_wallet) in ()


let test_non_oracle_update_oracle_fails =
	let (fa2_owner, fa2_contract) = bootstrap_fa2() in
	let other_wallet = Test.nth_bootstrap_account 1 in
	let _ = Test.set_source other_wallet in

	let _update_operator =
		let txndata : update_oracle = { new_oracle = other_wallet; } in
		let entrypoint : update_oracle contract =
			Test.to_entrypoint "update_oracle" fa2_contract in
		let res = Test.transfer_to_contract entrypoint txndata 0tez in

		Assert.failure_code res error_PERMISSIONS_DENIED in

	let updated_state = Test.get_storage fa2_contract in
		let _ = assert (updated_state.oracle = fa2_owner) in ()

