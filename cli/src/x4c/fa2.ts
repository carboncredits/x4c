
import { InMemorySigner } from '@taquito/signer';
import { TezosToolkit, MichelsonMap } from '@taquito/taquito';

class  FA2Contract {

    readonly contract: any;
    readonly tezos: TezosToolkit

    constructor(contract: any, oracle: InMemorySigner) {
        this.contract = contract;

        this.tezos = new TezosToolkit('https://rpc.jakartanet.teztnets.xyz');
        this.tezos.setProvider({signer: oracle});
    }

    add_token_id(token_id: number, metadata: Record<string, Uint8Array>) {
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
        .then((hash) => console.log(`Operation injected: https://ithaca.tzstats.com/${hash}`))
        .catch((error) => console.log(`Error: ${JSON.stringify(error, null, 2)}`));
    }

    mint(owner: string, token_id: number, amount: number) {
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
        .then((hash) => console.log(`Operation injected: https://ithaca.tzstats.com/${hash}`))
        .catch((error) => console.log(`Error: ${JSON.stringify(error, null, 2)}`));
    }
}

export {
    FA2Contract
}
