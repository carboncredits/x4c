import {Command, command, param} from 'clime';

import X4CClient from '../../x4c';

@command({
description: 'Define a new token ID',
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
        const client = X4CClient.getInstance()
        const fa2 = await client.getFA2Contact(contract_str, oracle_str)    
        fa2.add_token_id(token_id, {
            "title": Uint8Array.from(title.split('').map(letter => letter.charCodeAt(0))),
            "url": Uint8Array.from(url.split('').map(letter => letter.charCodeAt(0)))
        });
        return `Adding token...`;
    }
}
