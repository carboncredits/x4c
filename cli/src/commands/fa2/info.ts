import {Command, command, param} from 'clime';
import { TezosToolkit, MichelsonMap } from '@taquito/taquito';

import X4CClient from '../../x4c';

@command({
description: 'Fetch contract storage',
})
export default class extends Command {
	async execute(
		@param({
			description: 'FA2 Contract key (not needed if only one shows in info)',
			required: false,
		})
		contract_str: string,
	) {
		const client = X4CClient.getInstance()
		const fa2 = await client.getFA2Contact(contract_str)
		
		const storage = fa2.getStorage()
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