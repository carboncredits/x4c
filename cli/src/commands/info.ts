import {Command, command, metadata} from 'clime';
import {loadClientState, keys, contracts} from "../x4c"

@command({
    description: 'List keys and contracts saved by tezos-client',
})
export default class extends Command {
    @metadata
    async execute() {
        await loadClientState();

        console.log("Keys:")
        for (const key in keys) {
            const signer = keys[key];
            console.log("\t" + key + ": " + await signer.publicKeyHash());
        }
        console.log("Contracts:")
        for (const key in contracts) {
            const contract = contracts[key];
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