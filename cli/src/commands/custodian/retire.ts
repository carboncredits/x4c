import {Command, command, param} from 'clime';
import { TezosToolkit, MichelsonMap } from '@taquito/taquito';

import X4CClient from '../../x4c';
import CustodianContract from '../../x4c/CustodianContract';

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
        
        const signer = await client.signerForArg(oracle_str);
        if (signer === null) {
            return 'Oracle name not recognised.';
        }
        const contract = client.contractForArg(contract_str);
        if (contract === null) {
            return 'Contract name not recognised';
        }
        const fa2 = await client.hashForArg(fa2_str);
        
        const custodian = new CustodianContract(contract, signer)
        custodian.retire(fa2, token_id, amount, source_name, reason);
        
        return `Syncing tokens...`;
    }
}
