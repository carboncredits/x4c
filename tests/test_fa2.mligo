#import "./assert.mligo" "Assert"
#import "./common.mligo" "Common"

#include "../fa2.mligo"
type owner_fa2 = owner
type operator_fa2 = operator

let test_add_token_and_mint =
	let test_fa2 = Common.fa2_bootstrap() in

	let _ : test_exec_result = Common.fa2_add_token test_fa2 0n in
	let res = Common.fa2_mint_token test_fa2 0n test_fa2.owner 1_000_000n in
	let _: unit = Assert.tx_success(res) in

	let updated_state = Test.get_storage test_fa2.contract in
	let _test_metadata =
		let opt_token_metadata = Big_map.find_opt 0n updated_state.token_metadata in
		match opt_token_metadata with
			| None -> Test.failwith "No tokendata found"
			| Some _ -> ()
		in
	let _test_ledger =
		let owner = {token_owner = test_fa2.owner; token_id = 0n; } in
		let opt_ledger = Big_map.find_opt owner updated_state.ledger in
		match opt_ledger with
			| None -> Test.failwith ""
			| Some val -> assert (val = 1_000_000n)
		in ()

let test_mint_without_add_fails =
	let test_fa2 = Common.fa2_bootstrap() in

	let res = Common.fa2_mint_token test_fa2 0n test_fa2.owner 1_000_000n in
	let _ : unit = Assert.failure_code res error_TOKEN_UNDEFINED in ()


let test_add_existing_token_id_fails =
	let test_fa2 = Common.fa2_bootstrap() in
	let _ : unit = Test.set_source test_fa2.owner in

	let expected_metadata: token_metadata = {token_id = 42n; token_info = Map.literal[
		("test", Bytes.pack "foo")
	];} in

	let _initial_insert =
		let txndata_add_token_id : token_metadata list = [ expected_metadata; ] in
		let entrypoint_add_token_id : token_metadata list contract =
			Test.to_entrypoint "add_token_id" test_fa2.contract in
		let res = Test.transfer_to_contract entrypoint_add_token_id txndata_add_token_id 0tez in
		Assert.tx_success(res) in


	let current_state = Test.get_storage test_fa2.contract in
	let opt_current_metadata: token_metadata option = Big_map.find_opt 42n current_state.token_metadata in
	let _: unit = match opt_current_metadata with
		| None -> Test.failwith "Expected some current metadata"
		| Some val -> assert (val = expected_metadata)
	in

	let unexpected_metadata: token_metadata = {token_id = 42n; token_info = Map.literal[
		("test", Bytes.pack "bar")
	];} in

	let _repeat_insert =
		let txndata_add_token_id : token_metadata list = [ unexpected_metadata; ] in
		let entrypoint_add_token_id : token_metadata list contract =
			Test.to_entrypoint "add_token_id" test_fa2.contract in
		let res = Test.transfer_to_contract entrypoint_add_token_id txndata_add_token_id 0tez in
		Assert.failure_code res error_COLLISION in

	let updated_state = Test.get_storage test_fa2.contract in
	let opt_updated_metadata = Big_map.find_opt 42n updated_state.token_metadata in
	match opt_updated_metadata with
		| None -> Test.failwith "Expected some updated metadata"
		| Some val -> assert (val = expected_metadata)


let test_non_oracle_add_token_fails =
	let test_fa2 = Common.fa2_bootstrap() in
	let other_wallet = Test.nth_bootstrap_account 1 in
	let _ : unit = Test.set_source other_wallet in

	let _op_add_token_id =
		let txndata_add_token_id : token_metadata list =
			[ { token_id = 0n ; token_info = (Map.empty : (string, bytes) map) ; } ; ] in
		let entrypoint_add_token_id : token_metadata list contract =
			Test.to_entrypoint "add_token_id" test_fa2.contract in
		let res = Test.transfer_to_contract entrypoint_add_token_id txndata_add_token_id 0tez in

		Assert.failure_code res error_PERMISSIONS_DENIED in ()


let test_non_oracle_mint_fails =
	let test_fa2 = Common.fa2_bootstrap() in

	let _ : test_exec_result = Common.fa2_add_token test_fa2 0n in

	let _op_mint_tokens =
		let other_wallet = Test.nth_bootstrap_account 1 in
		let _ : unit = Test.set_source other_wallet in
		let txndata_mint_tokens : mint = [
			{ owner = test_fa2.owner ; token_id = 0n ; qty = 1_000_000n ; }
		] in
		let entrypoint_mint_tokens : mint contract =
			Test.to_entrypoint "mint" test_fa2.contract in

		let res = Test.transfer_to_contract entrypoint_mint_tokens txndata_mint_tokens 0tez in

		Assert.failure_code res error_PERMISSIONS_DENIED in ()


let test_update_oracle =
	let test_fa2 = Common.fa2_bootstrap() in
	let other_wallet = Test.nth_bootstrap_account 1 in
	let _ : unit = Test.set_source test_fa2.owner in

	let current_state = Test.get_storage test_fa2.contract in
		let _ : unit = assert (current_state.oracle = test_fa2.owner) in

	let _update_operator =
		let txndata : update_oracle = { new_oracle = other_wallet; } in
		let entrypoint : update_oracle contract =
			Test.to_entrypoint "update_oracle" test_fa2.contract in
		let res = Test.transfer_to_contract entrypoint txndata 0tez in

		Assert.tx_success(res) in

	let updated_state = Test.get_storage test_fa2.contract in
		let _ : unit = assert (updated_state.oracle = other_wallet) in ()


let test_non_oracle_update_oracle_fails =
	let test_fa2 = Common.fa2_bootstrap() in
	let other_wallet = Test.nth_bootstrap_account 1 in
	let _ : unit = Test.set_source other_wallet in

	let _update_operator =
		let txndata : update_oracle = { new_oracle = other_wallet; } in
		let entrypoint : update_oracle contract =
			Test.to_entrypoint "update_oracle" test_fa2.contract in
		let res = Test.transfer_to_contract entrypoint txndata 0tez in

		Assert.failure_code res error_PERMISSIONS_DENIED in

	let updated_state = Test.get_storage test_fa2.contract in
		let _ : unit = assert (updated_state.oracle = test_fa2.owner) in ()

