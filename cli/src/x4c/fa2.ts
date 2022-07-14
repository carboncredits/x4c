
import { InMemorySigner } from '@taquito/signer';
import { TezosToolkit, MichelsonMap } from '@taquito/taquito';

class  FA2Contract {

    readonly contract: any;

    constructor(contract: any) {
        this.contract = contract;
    }

    add_token_id(oracle: InMemorySigner, token_id: number, metadata: Record<string, Uint8Array>) {
        // I can't see how to set the provider once you have the contract, so we
        // have to refetch it
        const tezos = new TezosToolkit('https://rpc.jakartanet.teztnets.xyz');
        tezos.setProvider({signer: oracle});
        tezos.contract.at(this.contract.address).then((contract) => {
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

}

export {
    FA2Contract
}
