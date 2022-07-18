import * as Path from 'path';
import {CLI, Shim} from 'clime';
import X4CClient from './x4c';

// About everything we do needs us to have loaded the known keys
const client = X4CClient.getInstance()
client.loadClientState().then(() => {
    // The second parameter is the path to folder that contains command modules.
    let cli = new CLI('x4c', Path.join(__dirname, 'commands'));

    // Clime in its core provides an object-based command-line infrastructure.
    // To have it work as a common CLI, a shim needs to be applied:
    let shim = new Shim(cli);
    shim.execute(process.argv);
}).catch((err) => {
    console.log("Failed to load client state: ", err)
})

