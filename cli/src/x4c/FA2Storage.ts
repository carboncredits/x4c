import Tzstats from '../tzstats-client/Tzstats'
import {ContractStorage} from '../tzstats-client/types'
import { GenericClient } from './util';

type fa2 = {
	oracle: string;
	ledger: number;
	metdata: number;
	operators: [];
	token_metadata: number;
}

export default class FA2Storage {

	private readonly client: GenericClient;
	readonly contract_hash: string;

	private _info: ContractStorage | null = null;
	private _ledger: any | null = null;
	private _token_metadata: any | null = null;

	constructor(client: GenericClient, contact_hash: string) {
		this.client = client
		this.contract_hash = contact_hash
	}

	private async get_info(): Promise<fa2> {
		if (this._info === null) {
			this._info = await this.client.getContractStorage(this.contract_hash)
		}
		return <fa2>this._info.value;
	}

	async oracle_address(): Promise<string> {
		const info = await this.get_info();
		return info.oracle;
	}

	async ledger(): Promise<any> {
		if (this._ledger === null) {
			const info = await this.get_info();
			const resp = await this.client.getBigMapValues(info.ledger);
			if (this.client instanceof Tzstats) {
				this._ledger = resp.map((i : any) => ({
					...i,
					key: {
						token_owner: i.key[0],
						token_id: i.key[1]
					}
				}))
			} else {
				this._ledger = resp;
			}
		}
		return this._ledger;
	}

	async token_metadata(): Promise<any> {
		if (this._token_metadata === null) {
			const info = await this.get_info();
			// The key here is the token_id, so just "nat", and as such the response
			// from the two indexer types should be the same.
			this._token_metadata = await this.client.getBigMapValues(info.token_metadata);
		}
		return this._token_metadata;
	}
}
