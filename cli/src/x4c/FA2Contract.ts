
import { InMemorySigner } from '@taquito/signer';
import { TezosToolkit, MichelsonMap, Signer } from '@taquito/taquito';
import Tzkt from '../tzkt-client/Tzkt';

import Tzstats from '../tzstats-client/Tzstats'
import { EmitEvent } from '../tzstats-client/types';
import FA2Storage from './FA2Storage'
import { GenericClient } from './util';

export default class FA2Contract {
    private readonly node_base_url: string;
    private readonly indexer_api_base_url: string;

    readonly contract: any;
    readonly signer?: Signer;
    readonly tezos: TezosToolkit

    constructor(
        node_base_url: string,
        index_api_base_url: string,
        contract: any,
        signer?: Signer
    ) {
        this.node_base_url = node_base_url
        this.indexer_api_base_url = index_api_base_url

        this.contract = contract;
        this.signer = signer

        this.tezos = new TezosToolkit(node_base_url);
        if (signer) {
            this.tezos.setProvider({signer: signer});
        }
    }

    add_token_id(token_id: number, metadata: Record<string, Uint8Array>) {
        if (this.signer === undefined) {
            throw new Error('Signer for FA2 not provided')
        }
        // I can't see how to set the provider once you have the contract, so we
        // have to refetch it
        this.tezos.contract.at(this.contract.address).then((contract) => {
            return contract.methods.add_token_id([{
                token_id: token_id,
                token_info: MichelsonMap.fromLiteral(metadata)
            }]).send();
        })
        .then((op) => {
            console.log(`Awaiting for ${op.hash} to be confirmed...`);
            return op.confirmation().then(() => op.hash);
        })
        .then((hash) => console.log(`Operation injected: ${this.node_base_url}/${hash}`))
        .catch((error) => console.log(`Error: ${JSON.stringify(error, null, 2)}`));
    }

    mint(owner: string, token_id: number, amount: number) {
        if (this.signer === undefined) {
            throw new Error('Signer for FA2 not provided')
        }
        this.tezos.contract.at(this.contract.address).then((contract) => {
            return contract.methods.mint([{
                owner: owner,
                token_id: token_id,
                qty: amount
            }]).send();
        })
        .then((op) => {
            console.log(`Awaiting for ${op.hash} to be confirmed...`);
            return op.confirmation().then(() => op.hash);
        })
        .then((hash) => console.log(`Operation injected: ${this.node_base_url}/${hash}`))
        .catch((error) => console.log(`Error: ${JSON.stringify(error, null, 2)}`));
    }

    async transfer(receiver: string, token_id: number, amount: number) {
        if (this.signer === undefined) {
            throw new Error('Signer for FA2 not provided')
        }
        const from = await this.signer.publicKeyHash()
        this.tezos.contract.at(this.contract.address).then((contract) => {
            return contract.methods.transfer([{
                from_: from,
                txs: [{
                    to_: receiver,
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

    async retire(token_id: number, amount: number, reason: string) {
        if (this.signer === undefined) {
            throw new Error('Signer for FA2 not provided')
        }
        const from = await this.signer.publicKeyHash()
        this.tezos.contract.at(this.contract.address).then((contract) => {
            return contract.methods.retire([{
                retiring_party: from,
                token_id: token_id,
                amount: amount,
                retiring_data: Uint8Array.from(reason.split('').map(letter => letter.charCodeAt(0)))
            }]).send();
        })
        .then((op) => {
            console.log(`Awaiting for ${op.hash} to be confirmed...`);
            return op.confirmation().then(() => op.hash);
        })
        .then((hash) => console.log(`Operation injected: ${this.node_base_url}/${hash}`))
        .catch((error) => console.log(`Error: ${JSON.stringify(error, null, 2)}`));
    }

    getStorage(): FA2Storage {
        let client: GenericClient;
        if (this.indexer_api_base_url.includes("tzstats")) {
            client = new Tzstats(this.indexer_api_base_url);
        } else {
            client = new Tzkt(this.indexer_api_base_url);
        }
        return new FA2Storage(client, this.contract.address);
    }

	async getEvents(): Promise<EmitEvent[]> {
        let client: GenericClient;
        if (this.indexer_api_base_url.includes("tzstats")) {
            client = new Tzstats(this.indexer_api_base_url);
        } else {
            client = new Tzkt(this.indexer_api_base_url);
        }
		return client.getEvents(this.contract.address);
	}
}
