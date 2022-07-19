import {Command, command, param} from 'clime';

import X4CClient from '../../x4c';

@command({
description: 'Assign tokens to off chain entities.',
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
            description: 'FA2 contract key',
            required: true,
        })
        fa2_str: string,
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
            description: 'source name',
            required: false,
        })
        source_name: string,
        @param({
            description: 'target name',
            required: false,
        })
        target_name: string,
    ) {
        const client = X4CClient.getInstance()
        const custodian = await client.getCustodianContract(contract_str, oracle_str);        
        const fa2 = await client.hashForArg(fa2_str);
        
        custodian.internal_transfer(fa2, token_id, amount, source_name, target_name);
        
        return `Syncing tokens...`;
    }
}
