
import { readFile } from 'fs/promises';
import { homedir } from 'os';
import * as Path from 'path';

import { RemoteSigner } from '@taquito/remote-signer';
import { InMemorySigner } from '@taquito/signer';
import { TezosToolkit, MichelsonMap, Signer } from '@taquito/taquito';

import FA2Contract from './FA2Contract';
import CustodianContract from './CustodianContract';
import { GenericClient } from './util';
import Tzstats from '../tzstats-client/Tzstats';
import Tzkt from '../tzkt-client/Tzkt';

// The Taquito ContractAbstract generic can't be used for type specification (at
// least with my typescript knowledge), but I dislike have 'any' everywhere,
// so I make my own type for now until I git gud. The docs say the return type for
// a contract should be ContractProvider, but tsc doesn't agree with that.
type Contract = any
type TCPublicInfo = {name: string; value: string;}

export default class X4CClient {

    private readonly node_base_url: string;
    private readonly indexer_api_base_url: string;
    private readonly indexer_base_url: string;
    private readonly tezos_client_file_location: string;
    private readonly signatory_base_url: string;

    private _default_fa2_contract: Contract | null = null;
    private _contracts: Record<string, Contract> = {}
    private _keys: Record<string, InMemorySigner> = {}
    private _addresses: Record<string, RemoteSigner> = {}

    private static _instance: X4CClient

    // I don't really want a singleton system here, but clime doesn't make it
    // possible to pass objects around, so this is the quickest way to get a
    // global instance
    static getInstance(
        node_base_url = "https://rpc.kathmandunet.teztnets.xyz",
        indexer_api_base_url = "https://api.kathmandunet.tzkt.io",
        indexer_base_url = "https://kathmandunet.tzkt.io",
        signatory_base_url = 'http://signatory:6732' // based on docker-compose
    ) {
        return this._instance || (
            this._instance = new X4CClient(node_base_url, indexer_api_base_url, indexer_base_url, signatory_base_url)
        )
    }

    private constructor (
        node_base_url = "https://rpc.kathmandunet.teztnets.xyz",
        indexer_api_base_url = "https://api.tzkt.io",
        indexer_base_url = "https://tzkt.io",
        signatory_base_url = 'http://signatory:6732' // based on docker-compose
    ) {
        this.node_base_url = node_base_url;
        this.indexer_api_base_url = indexer_api_base_url;
        this.indexer_base_url = indexer_base_url;
        this.signatory_base_url = signatory_base_url;

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

    get addresses(): Record<string, RemoteSigner> {
        return this._addresses;
    }

    getIndexerUrl() {
        return this.indexer_base_url
    }

    getApiClient(): GenericClient {
        let client: GenericClient;
        if (this.indexer_api_base_url.includes("tzstats")) {
            client = new Tzstats(this.indexer_api_base_url);
        } else {
            client = new Tzkt(this.indexer_api_base_url);
        }
        return client;
    }

    private static isContractFA2(contract: Contract): boolean {
        // Obviously weak for now
        return contract.methods.mint !== undefined;
    }

    async loadClientState() {
        const tezos = new TezosToolkit(this.node_base_url);

        // if there's one and only one FA2 contract, note it as a default
        const fa2s: Contract[] = []

        console.log("Loading client state...")

        try {
            const contract_data = await readFile(Path.join(this.tezos_client_file_location, 'contracts'), 'utf8');
            if (contract_data !== undefined) {
                const contracts_list: TCPublicInfo[] = JSON.parse(contract_data)
                for (const item of contracts_list) {
                    const name = item.name;
                    const key = item.value;
                    const contract = await tezos.contract.at(key);
                    this.contracts[name] = contract;

                    if (X4CClient.isContractFA2(contract)) {
                        fa2s.push(contract);
                    }
                }
            }
        } catch { /* No file just means no data */ }

        if (fa2s.length === 1) {
            this._default_fa2_contract = fa2s[0];
        }

        try {
            const key_data = await readFile(Path.join(this.tezos_client_file_location, 'secret_keys'), 'utf8');
            if (key_data !== undefined) {
                const keys_list: TCPublicInfo[] = JSON.parse(key_data);
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
        } catch { /* No file just means no data */ }

        // It's not a given that any hashes without keys are stored in signatory in
        // general, but in the 4C app context I think we can assert this is, if not
        // true. something we're happy to see errors for if we mess our tezos-client
        // stores for :)
        try {
            const hash_data = await readFile(Path.join(this.tezos_client_file_location, 'public_key_hashs'), 'utf8');
            if (hash_data !== undefined) {
                const hash_list: TCPublicInfo[] = JSON.parse(hash_data);
                for (const item of hash_list) {
                    const name = item.name;
                    // if the name is in the other lists, just skip it - we're just looking for addresses
                    // that either we don't have the key for and are not our contracts
                    if ((this.keys[name] !== undefined) || (this.contracts[name] !== undefined)) {
                        continue;
                    }
                    const signer = new RemoteSigner(item.value, this.signatory_base_url);
                    this.addresses[name] = signer;
                }
            }
        } catch { /* No file just means no data */ }
    }

    async getFA2Contact(contract_str: string, signer_str?: string): Promise<FA2Contract> {
        const contract = this.contractForArg(contract_str);
        if (contract === undefined) {
            throw new Error('Contract name not recognised');
        }
        const signer = signer_str ? await this.signerForArg(signer_str) : undefined;
        return new FA2Contract(this.node_base_url, this.indexer_api_base_url, contract, signer);
    }

    async getCustodianContract(contract_str: string, signer_str?: string): Promise<CustodianContract> {
        const contract = this.contractForArg(contract_str);
        if (contract === undefined) {
            throw new Error(`Contract name not recognised: ${contract_str}`);
        }
        const signer = signer_str ? await this.signerForArg(signer_str) : undefined;
        return new CustodianContract(this.node_base_url, this.indexer_api_base_url, contract, signer);
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
        for (const name in this.addresses) {
            if (name === arg) {
                return await this.addresses[name].publicKeyHash();
            }
        }
        return arg;
    }

    async signerForArg(arg: string): Promise<Signer | undefined> {
        for (const name in this.keys) {
            const key = this.keys[name]
            if (name === arg) {
                return key;
            }
            if (await key.publicKeyHash() === arg) {
                return key;
            }
        }

        for (const name in this.addresses) {
            const key = this.addresses[name]
            if (name === arg) {
                return key;
            }
            if (await key.publicKeyHash() === arg) {
                return key;
            }
        }
        return undefined;
    }

    contractForArg(arg: string): Contract | undefined {
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
        return undefined;
    }

    async originateFA2Contract(
        contract_michelson: string,
        signer: Contract,
        contractOracle: string
    ): Promise<FA2Contract> {
        const tezos = new TezosToolkit(this.node_base_url);
        tezos.setProvider({signer: signer});
        // Note the docs for the tezos library imply that the contract
        // has to be in JSON format, but if you dig deeper they accept
        // michelson too.
        //
        // The library is not that smart either - the order of the arguments in
        // storage must match the michelson.
        return tezos.contract.originate({
            code: contract_michelson,
            storage: {
                ledger: MichelsonMap.fromLiteral({}),
                metadata: MichelsonMap.fromLiteral({}),
                operators: [],
                oracle: contractOracle,
                token_metadata: MichelsonMap.fromLiteral({})
            }
        })
        .then((originationOp) => {
            return originationOp.contract();
        })
        .then((contract) => {
            this._contracts[contract.address] = contract;
            // we store the default FA2 contract, so now we need to refresh that
            const fa2s: Contract[] = []
            for (const contract_address in this._contracts) {
                const contract = this._contracts[contract_address];
                if (X4CClient.isContractFA2(contract)) {
                    fa2s.push(contract);
                }
            }
            this._default_fa2_contract = fa2s.length === 1 ? fa2s[0] : null;

            return new FA2Contract(this.node_base_url, this.indexer_base_url, contract, signer)
        })
    }

    async originateCustodianContract(
        contract_michelson: string,
        signer: Contract,
        contractCustodian: string
    ): Promise<CustodianContract> {
        const tezos = new TezosToolkit(this.node_base_url);
        tezos.setProvider({signer: signer});
        // Note the docs for the tezos library imply that the contract
        // has to be in JSON format, but if you dig deeper they accept
        // michelson too.
        //
        // The library is not that smart either - the order of the arguments in
        // storage must match the michelson.
        return tezos.contract.originate({
            code: contract_michelson,
            storage: {
                custodian: contractCustodian,
                external_ledger: MichelsonMap.fromLiteral({}),
                ledger: MichelsonMap.fromLiteral({}),
                metadata: MichelsonMap.fromLiteral({}),
                operators: []
            }
        })
        .then((originationOp) => {
            return originationOp.contract();
        })
        .then((contract) => {
            this._contracts[contract.address] = contract;
            return new CustodianContract(this.node_base_url, this.indexer_base_url, contract, signer)
        })
    }
}

