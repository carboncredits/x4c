import {Command, command, param} from 'clime';
import { TezosToolkit, MichelsonMap } from '@taquito/taquito';

import {contractForArg, signerForArg, hashForArg} from '../../x4c';
import FA2Contract from '../../x4c/FA2Contract';

@command({
  description: 'Retire tokens from chain',
})
export default class extends Command {
  async execute(
    @param({
      description: 'Token owner key',
      required: true,
    })
    owner_str: string,
    @param({
      description: 'Token ID',
      required: true,
    })
    token_id: number,
    @param({
      description: 'Amount to retire',
      required: true,
    })
    amount: number,
    @param({
      description: 'Reason for retiring',
      required: true,
    })
    reason: string,
    @param({
      description: 'FA2 Contract key (not needed if only one shows in info)',
      required: false,
    })
    contract_str: string,
  ) {

    const signer = await signerForArg(owner_str);
    if (signer === null) {
        return 'Owner name not recognised.';
    }
    const contract = contractForArg(contract_str);
    if (contract === null) {
        return 'Contract name not recognised';
    }

    const fa2 = new FA2Contract(contract, signer)
    fa2.retire(token_id, amount, reason);

    return `Retiring tokens...`;
  }
}
