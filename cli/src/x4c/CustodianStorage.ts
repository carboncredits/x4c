import Tzstats from '../tzstats-client/Tzstats'
import {ContractStorage} from '../tzstats-client/types'

type custodian = {
	custodian: string;
	ledger: number;
	external_ledger: number;
	metadata: number;
}

export default class CustodianStorage {
	
	private readonly client: Tzstats;
	readonly contract_hash: string;
	
	private _info: ContractStorage | null = null;
	private _ledger: any | null = null;
	private _external_ledger: any | null = null;
	
	constructor(client: Tzstats, contact_hash: string) {
		this.client = client
		this.contract_hash = contact_hash
	}
	
	private async get_info(): Promise<custodian> {
		if (this._info === null) {
			this._info = await this.client.getContractStorage(this.contract_hash)
		}
		return <custodian>this._info.value;
	}
	
	async custodian_address(): Promise<string> {
		const info = await this.get_info();
		return info.custodian;
	}
	
	async ledger(): Promise<any> {
		if (this._ledger === null) {
			const info = await this.get_info();
			this._ledger = await this.client.getBigMapValues(info.ledger, false);
		}
		return this._ledger;
	}
	
}
