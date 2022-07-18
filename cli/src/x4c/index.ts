
import { readFile } from 'fs/promises';
import { homedir } from 'os';
import * as Path from 'path';

import { InMemorySigner } from '@taquito/signer';
import { TezosToolkit } from '@taquito/taquito';

import FA2Contract from './FA2Contract';
import CustodianContract from './CustodianContract';

// The Taquito ContractAbstract generic can't be used for type specification (at
// least with my typescript knowledge), but I dislike have 'any' everywhere,
// so I make my own type for now until I git gud. The docs say the return type for
// a contract should be ContractProvider, but tsc doesn't agree with that.
type Contract = any
type TCPublicInfo = {name: string; value: string;}

export default class X4CClient {
    
    private readonly node_base_url: string;
    private readonly indexer_base_url: string;    
    private readonly tezos_client_file_location: string;

    private _default_fa2_contract: Contract | null = null;
    private _contracts: Record<string, Contract> = {}
    private _keys: Record<string, InMemorySigner> = {}
    
    private static _instance: X4CClient
    
    // I don't really want a singleton system here, but clime doesn't make it
    // possible to pass objects around, so this is the quickest way to get a
    // global instance
    static getInstance(
        node_base_url: string = "https://rpc.jakartanet.teztnets.xyz",
        indexer_base_url: string = "https://api.tzstats.com/"
    ) {
        return this._instance || (
            this._instance = new X4CClient(node_base_url, indexer_base_url)
        )
    }
    
    private constructor (
        node_base_url: string = "https://rpc.jakartanet.teztnets.xyz",
        indexer_base_url: string = "https://api.tzstats.com/"
    ) {
        this.node_base_url = node_base_url;
        this.indexer_base_url = indexer_base_url;
        
        // we might want this configurable in future
        this.tezos_client_file_location = Path.join(homedir(), '.tezos-client')
    }
    
    get default_fa2_contract(): Contract | null {
        return this._default_fa2_contract;
    }
    
    get contracts(): Record<string, Contract> {
        return this._contracts;
    }
    
    get keys(): Record<string, InMemorySigner> {
        return this._keys;
    }
    
    async loadClientState() {
        const tezos = new TezosToolkit(this.node_base_url);
        
        // if there's one and only one FA2 contract, note it as a default
        let fa2s: Contract[] = []
        
        const contract_data = await readFile(Path.join(this.tezos_client_file_location, 'contracts'), 'utf8')
        if (contract_data !== undefined) {
            const contracts_list: [TCPublicInfo] = JSON.parse(contract_data)
            for (const item of contracts_list) {
                const name = item.name;
                const key = item.value;
                const contract = await tezos.contract.at(key);
                this.contracts[name] = contract;
        
                // This is obviously weak
                if (contract.methods.mint !== undefined) {
                    fa2s.push(contract);
                }
            }
        }
        if (fa2s.length === 1) {
            this._default_fa2_contract = fa2s[0];
        }
        
        const key_data = await readFile(Path.join(this.tezos_client_file_location, 'secret_keys'), 'utf8')
        if (key_data !== undefined) {
            const keys_list: [TCPublicInfo] = JSON.parse(key_data);
            for (const item of keys_list) {
                const name = item.name;
                let secret_key = item.value;
                if (secret_key.startsWith('unencrypted:')) {
                    secret_key = item.value.slice(12);
                }
                const signer = await InMemorySigner.fromSecretKey(secret_key);
                this.keys[name] = signer;
            }
        }
    }
    
    async getFA2Contact(contract_str: string, signer_str: string): Promise<FA2Contract> {
        const signer = await this.signerForArg(signer_str);
        if (signer === null) {
            throw new Error('Signer name not recognised.');
        }
        const contract = this.contractForArg(contract_str);
        if (contract === null) {
            throw new Error('Contract name not recognised');
        }
        return new FA2Contract(this.node_base_url, this.indexer_base_url, contract, signer);
    }
    
    async getCustodianContract(contract_str: string, signer_str: string): Promise<CustodianContract> {        
        const signer = await this.signerForArg(signer_str);
        if (signer === null) {
            throw new Error('Signer name not recognised.');
        }
        const contract = this.contractForArg(contract_str);
        if (contract === null) {
            throw new Error('Contract name not recognised');
        }
        return new CustodianContract(this.node_base_url, this.indexer_base_url, contract, signer);
    }
    
    async hashForArg(arg: string): Promise<string> {
        for (const name in this.keys) {
            if (name === arg) {
                return await this.keys[name].publicKeyHash();
            }
        }
        for (const name in this.contracts) {
            if (name === arg) {
                return this.contracts[name].address;
            }
        }
        return arg;
    }
    
    async signerForArg(arg: string): Promise<InMemorySigner | null> {
        for (const name in this.keys) {
            const key = this.keys[name]
            if (name === arg) {
                return key;
            }
            if (await key.publicKeyHash() === arg) {
                return key;
            }
        }
        return null;
    }
    
    contractForArg(arg: string): Contract | null {
        if (arg === undefined) {
            return this.default_fa2_contract;
        }
        for (const name in this.contracts) {
            const contract = this.contracts[name];
            if (name === arg) {
                return contract;
            }
            if (contract.address === arg) {
                return contract;
            }
        }
        return null;
    }
}

