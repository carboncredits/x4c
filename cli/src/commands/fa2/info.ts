import {Command, command, param} from 'clime';
import { TezosToolkit, MichelsonMap } from '@taquito/taquito';

import X4CClient from '../../x4c';

@command({
description: 'Fetch FA2 contract storage',
})
export default class extends Command {
	async execute(
		@param({
			description: 'FA2 contract key (not needed if only one shows in info)',
			required: false,
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
		const token_metadata = await storage.token_metadata()
		console.log('Token info:')
		for (const item of token_metadata) {
			const key = item.key;
			const value = item.value;
			console.log(`\t#${key}:`)
			console.log(value[1]);
			if (value[1] != {}) {
				for (const info of value[1]) {
					console.log(`\t\t${info}`)
				}
			}
		}
		
		return '';
	}
}
