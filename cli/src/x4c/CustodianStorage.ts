import {ContractStorage} from '../tzstats-client/types'

import { michelsonBytesToString, GenericClient } from './util'

type tzcustodian = {
	custodian: string;
	ledger: number;
	external_ledger: number;
	metadata: number;
	operators: [];
}

type CustodianLedgerEntry = {
	kyc: any;
	minter: string;
	token_id: number;
	amount: number;
}

export default class CustodianStorage {

	private readonly client: GenericClient;
	readonly contract_hash: string;

	private _info: ContractStorage | null = null;
	private _ledger: any | null = null;
	private _external_ledger: any | null = null;

	constructor(client: GenericClient, contact_hash: string) {
		this.client = client
		this.contract_hash = contact_hash
	}

	private async get_info(): Promise<tzcustodian> {
		if (this._info === null) {
			this._info = await this.client.getContractStorage(this.contract_hash)
		}
		return <tzcustodian>this._info.value;
	}

	async custodian_address(): Promise<string> {
		const info = await this.get_info();
		return info.custodian;
	}

	async ledger(): Promise<CustodianLedgerEntry[]> {
		if (this._ledger === null) {
			const info = await this.get_info();
			// Empty bigmaps seem to have a value of null
			if (info.ledger !== null) {
				this._ledger = await this.client.getBigMapValues(info.ledger);
			} else {
				return []
			}
		}
		return this._ledger.map((item: any) => {
			const key = item.key;
			const amount = item.value;
			return {
				kyc: michelsonBytesToString(key[0]),
				minter: key[1],
				token_id: parseInt(key[2]),
				amount: parseInt(amount)
			}
		});
	}
}
