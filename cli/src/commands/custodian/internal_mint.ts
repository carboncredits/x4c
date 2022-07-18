import {Command, command, param} from 'clime';
import { TezosToolkit, MichelsonMap } from '@taquito/taquito';

import X4CClient from '../../x4c';
import CustodianContract from '../../x4c/CustodianContract';

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
        
        const signer = await client.signerForArg(oracle_str);
        if (signer === null) {
            return 'Oracle name not recognised.';
        }
        const contract = client.contractForArg(contract_str);
        if (contract === null) {
            return 'Contract name not recognised';
        }
        const owner = await client.hashForArg(owner_str);
        
        const custodian = new CustodianContract(contract, signer)
        custodian.internal_mint(owner, token_id);
        
        return `Syncing tokens...`;
    }
}
