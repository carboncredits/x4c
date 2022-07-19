import {Command, command, metadata} from 'clime';
import Table from 'cli-table3';

import X4CClient from '../x4c';

const layout = { 'top': '' , 'top-mid': '' , 'top-left': '' , 'top-right': ''
 , 'bottom': '' , 'bottom-mid': '' , 'bottom-left': '' , 'bottom-right': ''
 , 'left': '' , 'left-mid': '' , 'mid': '' , 'mid-mid': ''
 , 'right': '' , 'right-mid': '' , 'middle': ' ' }

@command({
    description: 'List keys and contracts saved by tezos-client',
})
export default class extends Command {
    @metadata
    async execute() {
        const client = X4CClient.getInstance()
        
        const table = new Table({
            head: ['Alias', 'Hash', 'Contract type', 'Default'],
            chars: layout
        });
        for (const key in client.keys) {
            const signer = client.keys[key];
            table.push([key, await signer.publicKeyHash(), 'Wallet', '']);
        }
        for (const key in client.contracts) {
            const contract = client.contracts[key];
            let info = "Contact";
            if (contract.methods.mint !== undefined) {
                info = "FA2"
            }
            if (contract.methods.internal_mint !== undefined) {
                info = "Custodian"
            }                
            table.push([
               key,
               contract.address,
               info,
               contract === client.default_fa2_contract ? '✅' : ''
            ]);
        }
        console.log(table.toString());
    }
}
