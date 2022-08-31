#import "./assert.mligo" "Assert"
#import "./common.mligo" "Common"

#include "../fa2.mligo"
type storage_fa2 = storage
type entrypoint_fa2 = entrypoint

#include "../custodian.mligo"
type result_custodian = result
type owner_custodian = owner
type operator_custodian = operator

let test_internal_mint_with_tokens =
	let test_fa2 = Common.fa2_bootstrap() in
	let test_custodian = Common.custodian_bootstrap() in

	let _ = Common.fa2_add_token test_fa2 42n in
	let _ = Common.fa2_mint_token test_fa2 42n test_custodian.contract_address 1_000n in

	let res = Common.custodian_internal_mint test_custodian test_fa2 42n in
	let _ = Assert.tx_success(res) in

	let updated_state = Test.get_storage test_custodian.contract in
	let tok = { token_id = 42n; token_address = test_fa2.contract_address; } in
	let _test_ledger =
		let owner = { kyc = (Bytes.pack "self"); token = tok; } in
		let val = Big_map.find_opt owner updated_state.ledger in
		match val with
			| None ->  Test.failwith "Should be ledger entry"
			| Some val -> assert (val = 1_000n)
 		in
	let _test_ext_ledger =
		let val = Big_map.find_opt tok updated_state.external_ledger in
		match val with
			| None -> Test.failwith "Should be external ledger entry"
			| Some val -> assert (val = 1_000n)
		in ()


let test_internal_mint_without_tokens =
	let test_fa2 = Common.fa2_bootstrap() in
	let test_custodian = Common.custodian_bootstrap() in

	let _ = Common.fa2_add_token test_fa2 42n in
	let _ = Common.fa2_mint_token test_fa2 42n test_fa2.owner 1_000n in

	let res = Common.custodian_internal_mint test_custodian test_fa2 42n in
	let _ = Assert.tx_success(res) in

	let updated_state = Test.get_storage test_custodian.contract in
	let tok = { token_id = 42n; token_address = test_fa2.contract_address; } in
	let _test_ledger =
		let owner = { kyc = (Bytes.pack "self"); token = tok; } in
		let val = Big_map.find_opt owner updated_state.ledger in
		match val with
			| None ->  ()
			| Some _ -> Test.failwith "Did not expect ledger entry"
		 in
	let _test_ext_ledger =
		let val = Big_map.find_opt tok updated_state.external_ledger in
		match val with
			| None -> ()
			| Some _ -> Test.failwith "Did not expect external_ledger entry"
		in ()


let test_retire =
	let test_fa2 = Common.fa2_bootstrap() in
	let test_custodian = Common.custodian_bootstrap() in

	let _ = Common.fa2_add_token test_fa2 42n in
	let _ = Common.fa2_mint_token test_fa2 42n test_custodian.contract_address 1_000n in
	let _ = Common.custodian_internal_mint test_custodian test_fa2 42n in

	let retire_data = {
		retiring_party_kyc = (Bytes.pack "self") ;
		token_id = 42n ;
		amount = 350n ;
		retiring_data = (Bytes.pack "this is for testing") ;
	} in
	let res = Common.custodian_retire test_custodian test_fa2 retire_data in
	let _ = Assert.tx_success(res) in

	let custodian_state = Test.get_storage test_custodian.contract in
	let tok = { token_id = 42n; token_address = test_fa2.contract_address; } in
	let _test_ledger =
		let owner = { kyc = (Bytes.pack "self"); token = tok; } in
		let val = Big_map.find_opt owner custodian_state.ledger in
		match val with
			| None ->  Test.failwith "Should be ledger entry"
			| Some val -> assert (val = 650n)
		 in
	let _test_ext_ledger =
		let val = Big_map.find_opt tok custodian_state.external_ledger in
		match val with
			| None -> Test.failwith "Should be external ledger entry"
			| Some val -> assert (val = 650n)
		in

	let fa2_state = Test.get_storage test_fa2.contract in
	let _test_ledger =
		let owner = { token_owner = test_custodian.contract_address; token_id = 42n; } in
		let val = Big_map.find_opt owner fa2_state.ledger in
		match val with
			| None -> Test.failwith "Should be a ledger entry"
			| Some val -> assert (val = 650n)
		in ()
