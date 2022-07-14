import {Command, command, param} from 'clime';
import { TezosToolkit, MichelsonMap } from '@taquito/taquito';

import {contractForArg, signerForArg, hashForArg} from '../../x4c';
import {CustodianContract} from '../../x4c/custodian';

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

    const signer = await signerForArg(oracle_str);
    if (signer === null) {
        return 'Oracle name not recognised.';
    }
    const contract = contractForArg(contract_str);
    if (contract === null) {
        return 'Contract name not recognised';
    }
    const owner = await hashForArg(owner_str);

    const custodian = new CustodianContract(contract, signer)
    custodian.internal_transfer(owner, token_id, amount, source_name, target_name);

    return `Syncing tokens...`;
  }
}
