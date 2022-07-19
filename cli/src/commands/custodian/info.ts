import {Command, command, param} from 'clime';
import { TezosToolkit, MichelsonMap } from '@taquito/taquito';

import X4CClient from '../../x4c';

@command({
description: 'Fetch custodian contract storage',
})
export default class extends Command {
	async execute(
		@param({
			description: 'Custodian contract key',
			required: true,
		})
		contract_str: string,
	) {
		const client = X4CClient.getInstance()
		const contract = await client.getFA2Contact(contract_str)
		
		const storage = contract.getStorage()
		console.log('Oracle: ', await storage.oracle_address())
		const ledger = await storage.ledger()
		console.log('Ledger:')
		for (const item of ledger) {
			const key = item.key;
			const value = item.value;
			console.log(`\t${key[0]}:#${key[1]} \t${value} tokens`);
		}
		
		return '';
	}
}
