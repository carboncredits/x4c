import {Command, command, param} from 'clime';
import { TezosToolkit, MichelsonMap } from '@taquito/taquito';

import X4CClient from '../../x4c';

@command({
description: 'Retire tokens from custorian.',
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
            description: 'source name',
            required: true,
        })
        source_name: string,
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
            description: 'Reason for retiring',
            required: true,
        })
        reason: string,
    ) {
        const client = X4CClient.getInstance()
        const custodian = await client.getCustodianContract(contract_str, oracle_str);
        const fa2 = await client.hashForArg(fa2_str);
        
        custodian.retire(fa2, token_id, amount, source_name, reason);
        
        return `Syncing tokens...`;
    }
}
