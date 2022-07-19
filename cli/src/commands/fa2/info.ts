import {Command, command, param} from 'clime';
import Table from 'cli-table3';

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
		const table = new Table({
			head: ['ID', 'Owner', 'Tokens'],
			chars: { 'top': '' , 'top-mid': '' , 'top-left': '' , 'top-right': '', 'bottom': '' , 	'bottom-mid': '' , 'bottom-left': '' , 'bottom-right': '', 
				'left': '' , 'left-mid': '' , 'mid': '' , 'mid-mid': '', 
				'right': '' , 'right-mid': '' , 'middle': ' '
			}
		});
		for (const item of ledger) {
			const key = item.key;
			const value = item.value;
			table.push([key[1], key[0], value]);
		}		
		console.log(table.toString());
		
		// const token_metadata = await storage.token_metadata()
		// console.log('Token info:')
		// for (const item of token_metadata) {
		// 	const key = item.key;
		// 	const value = item.value;
		// 	console.log(`\t#${key}:`)
		// 	console.log(value[1]);
		// 	if (value[1] != {}) {
		// 		for (const info of value[1]) {
		// 			console.log(`\t\t${info}`)
		// 		}
		// 	}
		// }
		// 
		
		return '';
	}
}
