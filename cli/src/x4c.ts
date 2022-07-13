
import { readFile } from 'fs/promises';
import { homedir } from 'os';
import { join } from 'path';

import { InMemorySigner } from '@taquito/signer';
import { TezosToolkit } from '@taquito/taquito';
const tezos = new TezosToolkit('https://rpc.jakartanet.teztnets.xyz');

let contracts: Record<string, any> = {}
let keys: Record<string, InMemorySigner> = {}

type TCPublicInfo = {name: string; value: string;}


async function loadClientState() {
    const contract_data = await readFile(join(homedir(), '.tezos-client/contracts'), 'utf8')
        .catch((err) => { console.log("Failed to get clients: ", err)});
    if (contract_data !== undefined) {
        const contracts_list: [TCPublicInfo] = JSON.parse(contract_data)
        for (const item of contracts_list) {
            const name = item.name;
            const key = item.value;
            const contract = await tezos.contract.at(key);
            contracts[name] = contract;
        }
    }
    const key_data = await readFile(join(homedir(), '.tezos-client/secret_keys'), 'utf8')
        .catch((err) => { console.log("Failed to get keys: ", err)});
    if (key_data !== undefined) {
        const keys_list: [TCPublicInfo] = JSON.parse(key_data);
        for (const item of keys_list) {
            const name = item.name;
            let secret_key = item.value;
            if (secret_key.startsWith('unencrypted:')) {
                secret_key = item.value.slice(12);
            }
            const signer = await InMemorySigner.fromSecretKey(secret_key);
            keys[name] = signer;
        }
    }
}

export {
    loadClientState,
    keys,
    contracts
};
