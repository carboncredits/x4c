import {Command, command, param} from 'clime';
import { TezosToolkit, MichelsonMap } from '@taquito/taquito';

import {contractForArg, signerForArg, hashForArg} from '../../x4c';
import FA2Contract from '../../x4c/FA2Contract';

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

    const signer = await signerForArg(oracle_str);
    if (signer === null) {
        return 'Oracle name not recognised.';
    }
    const contract = contractForArg(contract_str);
    if (contract === null) {
        return 'Contract name not recognised';
    }
    const owner = await hashForArg(owner_str);

    const fa2 = new FA2Contract(contract, signer)
    fa2.mint(owner, token_id, amount);

    return `Minting tokens...`;
  }
}
