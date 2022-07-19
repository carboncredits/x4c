import {Command, command, param} from 'clime';

import X4CClient from '../../x4c';

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
        const fa2 = await client.getFA2Contact(contract_str, owner_str)
        
        const receiver = await client.hashForArg(receiver_str);
        
        fa2.transfer(receiver, token_id, amount);
        
        return `Transfering tokens...`;
    }
}
