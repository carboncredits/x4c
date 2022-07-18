
import Tzstats from '../tzstats-client/Tzstats'
import {ContractStorage} from '../tzstats-client/types'


type fa2 = {
	oracle: string;
	ledger: number;
	metdata: number;
	operators: number;
	token_metadata: number;
}


export default class FA2Storage {
	
	private readonly client: Tzstats;
	readonly contract_hash: string;
	
	private _info: ContractStorage | null = null;
	private _ledger: any | null = null;
	
	constructor(client: Tzstats, contact_hash: string) {
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
			this._ledger = await this.client.getBigMapValues(info.ledger, false);
		}
		return this._ledger;
	}
}