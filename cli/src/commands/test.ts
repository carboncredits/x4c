import {Command, command, param} from 'clime';

import { TezosToolkit } from '@taquito/taquito';
const tezos = new TezosToolkit('https://rpc.jakartanet.teztnets.xyz');




@command({
  description: 'This is a command for printing a greeting message',
})
export default class extends Command {
  async execute(
    @param({
      description: 'Your loud name',
      required: true,
    })
    name: string,
  ) {

    tezos.contract
        .at('KT1JuohUpviPwoTCtHRo38V6T4goU8QxdE7w')
        .then((c) => {
            let methods = c.parameterSchema.ExtractSignatures();
            console.log(JSON.stringify(methods, null, 2));
        })
        .catch((error) => console.log(`Error: ${error}`));

    return `Hello, ${name}!`;
  }
}