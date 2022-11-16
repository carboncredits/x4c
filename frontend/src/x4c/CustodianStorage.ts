import Tzstats from '../tzstats-client/Tzstats'
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

type CustodianOperator = {
	kyc: any;
	operator: string;
	token_id: number;
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
				const resp = await this.client.getBigMapValues(info.ledger);
				if (this.client instanceof Tzstats) {
					this._ledger = resp.map((i : any) => ({
						...i,
						key: {
							kyc: i.key[0],
							token: {
								token_address: i.key[1],
								token_id: i.key[2]
							}
						}
					}))
				} else {
					this._ledger = resp;
				}
			} else {
				return []
			}
		}
		return this._ledger.map((item: any) => {
			const key = item.key;
			const amount = item.value;
			return {
				kyc: michelsonBytesToString(key.kyc),
				minter: key.token.token_address,
				token_id: parseInt(key.token.token_id),
				amount: parseInt(amount)
			}
		});
	}

	async operators(): Promise<CustodianOperator[]> {
		const info = await this.get_info();
		const operators = info.operators;
		return operators.map((item: any) => {
			return {
				kyc: michelsonBytesToString(item.token_owner),
				operator: item.token_operator,
				token_id: item.token_id
			}
		});
	}
}
