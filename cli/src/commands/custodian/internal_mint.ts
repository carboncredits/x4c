import {Command, command, param} from 'clime';

import X4CClient from '../../x4c';

@command({
description: 'Synchronise token status for custodian with main FA2 contract.',
})
export default class extends Command {
    async execute(
        @param({
            description: 'Custodian Oracle Key',
            required: true,
        })
        oracle_str: string,
        @param({
            description: 'Custodian Contract key',
            required: true,
        })
        contract_str: string,
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
    ) {
        const client = X4CClient.getInstance()
        const custodian = await client.getCustodianContract(contract_str, oracle_str)        
        const owner = await client.hashForArg(owner_str);

        custodian.internal_mint(owner, token_id);
        
        return `Syncing tokens...`;
    }
}
