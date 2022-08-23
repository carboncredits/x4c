import * as Path from 'path';
import { env } from 'node:process';
import {CLI, Shim} from 'clime';
import X4CClient from './x4c';

let rpc_node_url = env.TEZOS_RPC_HOST;
let indexer_url = env.TEZOS_INDEX_HOST;

// About everything we do needs us to have loaded the known keys
const client = X4CClient.getInstance(rpc_node_url, indexer_url, indexer_url);
client.loadClientState().then(() => {
    const cli = new CLI('x4c', Path.join(__dirname, 'commands'));
    const shim = new Shim(cli);
    shim.execute(process.argv);
}).catch((err) => {
    console.log("Failed to load client state: ", err)
})

