import {Command, command, param} from 'clime';

import X4CClient from '../../x4c';

@command({
description: 'Mint new tokens',
})
export default class extends Command {
    async execute(
        @param({
            description: 'FA2 Oracle Key',
            required: true,
        })
        oracle_str: string,
        @param({
            description: 'Owner of tokens key',
            required: true,
        })
        owner_str: string,
        @param({
            description: 'Token ID',
            required: true,
        })
        token_id: number,
        @param({
            description: 'Amount to mint',
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
        const fa2 = await client.getFA2Contact(contract_str, oracle_str)
        const owner = await client.hashForArg(owner_str);
        
        fa2.mint(owner, token_id, amount);
        
        return `Minting tokens...`;
    }
}
