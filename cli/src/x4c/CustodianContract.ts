import { InMemorySigner } from '@taquito/signer';
import { TezosToolkit } from '@taquito/taquito';

import { GenericClient, stringToMichelsonBytes } from "./util"
import Tzstats from '../tzstats-client/Tzstats'
import CustodianStorage from './CustodianStorage'
import Tzkt from '../tzkt-client/Tzkt';

export default class  CustodianContract {
    private readonly node_base_url: string;
    private readonly indexer_api_base_url: string;    

    readonly contract: any;
    readonly tezos: TezosToolkit

    constructor(
        node_base_url: string,
        index_api_base_url: string,
        contract: any, 
        oracle?: InMemorySigner
    ) {
        this.node_base_url = node_base_url
        this.indexer_api_base_url = index_api_base_url
        
        this.contract = contract;

        this.tezos = new TezosToolkit('https://rpc.jakartanet.teztnets.xyz');
        if (oracle) {
            this.tezos.setProvider({signer: oracle});
        }
    }

    internal_mint(fa2_contract: string, token_id: number) {
        if (this.tezos.signer === undefined) {
            throw new Error('Oracle for custodian not provided')
        } 
        this.tezos.contract.at(this.contract.address).then((contract) => {
            return contract.methods.internal_mint([{
                token_id: token_id,
                token_address: fa2_contract
            }]).send();
        })
        .then((op) => {
            console.log(`Awaiting for ${op.hash} to be confirmed...`);
            return op.confirmation().then(() => op.hash);
        })
        .then((hash) => console.log(`Operation injected: ${this.node_base_url}/${hash}`))
        .catch((error) => console.log(`Error: ${JSON.stringify(error, null, 2)}`));
    }

    internal_transfer(fa2_contract: string, token_id: number, amount: number, source_name: string, target_name: string) {
        if (this.tezos.signer === undefined) {
            throw new Error('Oracle for custodian not provided')
        } 
        if (source_name === undefined) {
            source_name = "self";
        }
        if (target_name === undefined) {
            target_name = "self"
        }

        this.tezos.contract.at(this.contract.address).then((contract) => {
            return contract.methods.internal_transfer([{
                from_: stringToMichelsonBytes(source_name),
                token_address: fa2_contract,
                txs: [{
                    to_: stringToMichelsonBytes(target_name),
                    token_id: token_id,
                    amount: amount
                }]
            }]).send();
        })
        .then((op) => {
            console.log(`Awaiting for ${op.hash} to be confirmed...`);
            return op.confirmation().then(() => op.hash);
        })
        .then((hash) => console.log(`Operation injected: ${this.node_base_url}/${hash}`))
        .catch((error) => console.log(`Error: ${JSON.stringify(error, null, 2)}`));
    }

    async retire(fa2_contract: string, token_id: number, amount: number, source_name: string, reason: string): Promise<string> {
        if (this.tezos.signer === undefined) {
            throw new Error('Oracle for custodian not provided')
        } 
        if (source_name === undefined) {
            source_name = "self";
        }

        return this.tezos.contract.at(this.contract.address).then((contract) => {
            return contract.methods.retire([{
                token_address: fa2_contract,
                txs: [{
                    retiring_party_kyc: stringToMichelsonBytes(source_name),
                    token_id: token_id,
                    amount: amount,
                    retiring_data: Uint8Array.from(reason.split('').map(letter => letter.charCodeAt(0)))
                }]
            }]).send();
        })
        .then((op) => {
            console.log(`Awaiting for ${op.hash} to be confirmed...`);
            return op.confirmation().then(() => op.hash);
        })
    }
    
    getStorage(): CustodianStorage {
        let client: GenericClient;
        if (this.indexer_api_base_url.includes("tzstats")) {
            client = new Tzstats(this.indexer_api_base_url);    
        } else {
            client = new Tzkt(this.indexer_api_base_url);
        }
        return new CustodianStorage(client, this.contract.address);
    }
}
