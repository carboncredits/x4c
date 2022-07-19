import * as Path from 'path';
import {CLI, Shim} from 'clime';
import X4CClient from './x4c';

// About everything we do needs us to have loaded the known keys
const client = X4CClient.getInstance()
client.loadClientState().then(() => {
    const cli = new CLI('x4c', Path.join(__dirname, 'commands'));
    const shim = new Shim(cli);
    shim.execute(process.argv);
}).catch((err) => {
    console.log("Failed to load client state: ", err)
})

