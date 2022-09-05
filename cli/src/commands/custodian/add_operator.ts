import {Command, command, param} from 'clime';

import X4CClient from '../../x4c';

@command({
description: 'Add an operator from the contract.',
})
export default class extends Command {
	async execute(
		@param({
			description: 'Custodian Oracle Key',
			required: true,
		})
		oracle_str: string,
		@param({
			description: 'Custodian Contract key',
			required: true,
		})
		contract_str: string,
		@param({
			description: 'Operator Key',
			required: true,
		})
		operator_str: string,
		@param({
			description: 'Token ID',
			required: true,
		})
		token_id: number,
		@param({
			description: 'Token owner name',
			required: true,
		})
		token_owner: string,
	) {
		const client = X4CClient.getInstance()
		const custodian = await client.getCustodianContract(contract_str, oracle_str)
		const operator = await client.hashForArg(operator_str);

		custodian.add_operator(operator, token_id, token_owner);

		return `Adding operator...`;
	}
}
