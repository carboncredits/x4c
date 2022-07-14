import {Command, command, param} from 'clime';
import { TezosToolkit, MichelsonMap } from '@taquito/taquito';

import {contractForArg, signerForArg} from '../../x4c';

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

    // I can't see how to set the provider once you have the contract, so we
    // have to refetch it
    const tezos = new TezosToolkit('https://rpc.jakartanet.teztnets.xyz');
    tezos.setProvider({signer: signer});
    tezos.contract.at(contract.address).then((contract) => {
        return contract.methods.add_token_id([{
            token_id: token_id,
            token_info:  MichelsonMap.fromLiteral({
                "title": Uint8Array.from(title.split('').map(letter => letter.charCodeAt(0))),
                "url": Uint8Array.from(url.split('').map(letter => letter.charCodeAt(0)))
            })
        }]).send();
    })
    .then((op) => {
        console.log(`Awaiting for ${op.hash} to be confirmed...`);
        return op.confirmation().then(() => op.hash);
    })
    .then((hash) => console.log(`Operation injected: https://ithaca.tzstats.com/${hash}`))
    .catch((error) => console.log(`Error: ${JSON.stringify(error, null, 2)}`));

    return `Adding token...`;
  }
}
