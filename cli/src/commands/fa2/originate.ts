import { readFile, writeFile } from 'fs/promises';
import { homedir } from 'os';
import * as Path from 'path';

import {Command, command, param} from 'clime';

import X4CClient from '../../x4c';

@command({
	description: 'Create new FA2 contract instance on chain',
})
export default class extends Command {
	async execute(
		@param({
			description: 'Alias for contract',
			required: true,
		})
		alias: string,
		@param({
			description: 'Contract file location',
			required: true,
		})
		contract_path: string,
		@param({
			description: 'Signer key hash (who will pay to load contract)',
			required: true,
		})
		signer_str: string,
		@param({
			description: 'Oracle key hash (if not specifed, set to same as signer)',
			required: false,
		})
		oracle_str: string,
	) {
		const client = X4CClient.getInstance();
		
		// don't let the alias be used if it's already a thing
		if (await client.hashForArg(alias) !== alias) {
			throw new Error(`Alias ${alias} already exists`);
		}
		
		const signer = await client.signerForArg(signer_str);
		if (signer === undefined) {
			throw new Error(`Failed to find signer ${signer_str}`);
		}
		
		if (!oracle_str) {
			oracle_str = signer_str;
		}
		const oracle = await client.hashForArg(oracle_str);		
		const contract_michelson = await readFile(contract_path, 'utf-8');

		const contract = await client.originateFA2Contract(contract_michelson, signer, oracle);
		console.log(`Contract originated as ${contract.contract.address}`)
		
		// add the contract to the tezos-client info
		const contracts_path = Path.join(homedir(), '.tezos-client/contracts')
		const contracts_data = await readFile(contracts_path, 'utf8')
		let contracts_list = [];
		if (contracts_data !== undefined) {
			contracts_list = JSON.parse(contracts_data)
		}
		contracts_list.push({
			name: alias,
			value: contract.contract.address
		})
		await writeFile(contracts_path, JSON.stringify(contracts_list))
		
		return '';
	}
}
