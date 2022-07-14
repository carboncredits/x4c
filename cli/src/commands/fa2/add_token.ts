import {Command, command, param} from 'clime';

@command({
  description: 'Define a new token',
})
export default class extends Command {
  execute(
    @param({
      description: 'FA2 Oracle Key',
      required: true,
    })
    oracle: string,
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
    contract: string,
  ) {
    return `Hello, stuff!`;
  }
}