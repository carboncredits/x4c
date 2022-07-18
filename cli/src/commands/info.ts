import {Command, command, metadata} from 'clime';
import X4CClient from '../x4c';

@command({
    description: 'List keys and contracts saved by tezos-client',
})
export default class extends Command {
    @metadata
    async execute() {
        const client = X4CClient.getInstance()
        
        console.log("Keys:")
        for (const key in client.keys) {
            const signer = client.keys[key];
            console.log("\t" + key + ": " + await signer.publicKeyHash());
        }
        console.log("Contracts:")
        for (const key in client.contracts) {
            const contract = client.contracts[key];
            let info = "";
            if (contract.methods.mint !== undefined) {
                info = " (FA2)"
            }
            if (contract.methods.internal_mint !== undefined) {
                info = " (Custodian)"
            }
            console.log("\t" + key + info + ": " + contract.address)
        }
    }
}
