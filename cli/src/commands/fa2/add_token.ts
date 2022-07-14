import {Command, command, param} from 'clime';
import { TezosToolkit, MichelsonMap } from '@taquito/taquito';

import {contractForArg, signerForArg} from '../../x4c';
import {FA2Contract} from '../../x4c/fa2';

@command({
  description: 'Define a new token',
})
export default class extends Command {
  async execute(
    @param({
      description: 'FA2 Oracle Key',
      required: true,
    })
    oracle_str: string,
    @param({
      description: 'Token ID',
      required: true,
    })
    token_id: number,
    @param({
      description: 'Project Title',
      required: true,
    })
    title: string,
    @param({
      description: 'Project URL',
      required: true,
    })
    url: string,
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

    const fa2 = new FA2Contract(contract)
    fa2.add_token_id(signer, token_id, {
        "title": Uint8Array.from(title.split('').map(letter => letter.charCodeAt(0))),
        "url": Uint8Array.from(url.split('').map(letter => letter.charCodeAt(0)))
    });

    return `Adding token...`;
  }
}
