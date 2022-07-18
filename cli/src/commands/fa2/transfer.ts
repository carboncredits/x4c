import {Command, command, param} from 'clime';
import { TezosToolkit, MichelsonMap } from '@taquito/taquito';

import X4CClient from '../../x4c';
import FA2Contract from '../../x4c/FA2Contract';

@command({
    description: 'Assign tokens to another address',
})
export default class extends Command {
    async execute(
        @param({
            description: 'Token owner key',
            required: true,
        })
        owner_str: string,
        @param({
            description: 'Token receiver key',
            required: true,
        })
        receiver_str: string,
        @param({
            description: 'Token ID',
            required: true,
        })
        token_id: number,
        @param({
            description: 'Amount to transfer',
            required: true,
        })
        amount: number,
        @param({
            description: 'FA2 Contract key (not needed if only one shows in info)',
            required: false,
        })
        contract_str: string,
    ) {
        const client = X4CClient.getInstance()
        
        const signer = await client.signerForArg(owner_str);
        if (signer === null) {
            return 'Owner name not recognised.';
        }
        const contract = client.contractForArg(contract_str);
        if (contract === null) {
            return 'Contract name not recognised';
        }
        const receiver = await client.hashForArg(receiver_str);
        
        const fa2 = new FA2Contract(contract, signer)
        fa2.transfer(receiver, token_id, amount);
        
        return `Transfering tokens...`;
    }
}
