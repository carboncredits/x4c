import {Command, command, param} from 'clime';
import Table from 'cli-table3';

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
		const contract = await client.getCustodianContract(contract_str)

		const storage = contract.getStorage()
		console.log('Custodian: ', await storage.custodian_address())

		const ledger = await storage.ledger()
		console.log('Ledger:')
		const table = new Table({
			head: ['KYC', 'Minter', 'ID', 'Amount'],
			chars: { 'top': '' , 'top-mid': '' , 'top-left': '' , 'top-right': '', 'bottom': '' , 	'bottom-mid': '' , 'bottom-left': '' , 'bottom-right': '',
				'left': '' , 'left-mid': '' , 'mid': '' , 'mid-mid': '',
				'right': '' , 'right-mid': '' , 'middle': ' '
			}
		});
		for (const item of ledger) {
			table.push([item.kyc, item.minter, item.token_id, item.amount])
		}
		console.log(table.toString());

		const operators = await storage.operators()
		console.log('Operators:')
		const optable = new Table({
			head: ['Operator', 'KYC', 'Token ID'],
			chars:  { 'top': '' , 'top-mid': '' , 'top-left': '' , 'top-right': '', 'bottom': '' , 	'bottom-mid': '' , 'bottom-left': '' , 'bottom-right': '',
				'left': '' , 'left-mid': '' , 'mid': '' , 'mid-mid': '',
				'right': '' , 'right-mid': '' , 'middle': ' '
			}
		});
		for (const operator of operators) {
			optable.push([operator.operator, operator.kyc, operator.token_id])
		}
		console.log(optable.toString());

		const events = await contract.getEvents()
		console.log('Events:')
		const eventsTable = new Table({
			head: ['ID', 'Tag', 'Time', 'Payload'],
			chars: { 'top': '' , 'top-mid': '' , 'top-left': '' , 'top-right': '', 'bottom': '' , 	'bottom-mid': '' , 'bottom-left': '' , 'bottom-right': '',
				'left': '' , 'left-mid': '' , 'mid': '' , 'mid-mid': '',
				'right': '' , 'right-mid': '' , 'middle': ' '
			}
		});
		for (const event of events) {
			const payload = Buffer.from(event.payload ,"hex").toString()
			eventsTable.push([event.id.toString(), event.tag, event.time.toISOString(), payload]);
		}
		console.log(eventsTable.toString());

		return '';
	}
}
