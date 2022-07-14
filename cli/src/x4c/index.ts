
import { readFile } from 'fs/promises';
import { homedir } from 'os';
import { join } from 'path';

import { InMemorySigner } from '@taquito/signer';
import { TezosToolkit } from '@taquito/taquito';


// The Taquito ContractAbstract generic can't be used for type specification (at
// least with my typescript knowledge), but I dislike have 'any' everywhere,
// so I make my own type for now until I git gud. The docs say the return type for
// a contract should be ContractProvider, but tsc doesn't agree with that.
type Contract = any

let contracts: Record<string, Contract> = {}
let keys: Record<string, InMemorySigner> = {}

let default_fa2_contract: Contract | null = null;

type TCPublicInfo = {name: string; value: string;}


async function loadClientState() {
    const tezos = new TezosToolkit('https://rpc.jakartanet.teztnets.xyz');

    // if there's one and only one FA2 contract, note it as a default
    let fa2s: Contract[] = []

    const contract_data = await readFile(join(homedir(), '.tezos-client/contracts'), 'utf8')
        .catch((err) => { console.log("Failed to get clients: ", err)});
    if (contract_data !== undefined) {
        const contracts_list: [TCPublicInfo] = JSON.parse(contract_data)
        for (const item of contracts_list) {
            const name = item.name;
            const key = item.value;
            const contract = await tezos.contract.at(key);
            contracts[name] = contract;

            if (contract.methods.mint !== undefined) {
                fa2s.push(contract);
            }
        }
    }
    if (fa2s.length === 1) {
        default_fa2_contract = fa2s[0];
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

async function signerForArg(arg: string): Promise<InMemorySigner | null> {
    for (const name in keys) {
        const key = keys[name]
        if (name === arg) {
            return key;
        }
        if (await key.publicKeyHash() === arg) {
            return key;
        }
    }
    return null;
}

function contractForArg(arg: string): Contract | null {
    if (arg === undefined) {
        return default_fa2_contract;
    }
    for (const name in contracts) {
        const contract = contracts[name];
        if (name === arg) {
            return contract;
        }
        if (contract.address === arg) {
            return contract;
        }
    }
    return null;
}

export {
    loadClientState,
    contractForArg,
    signerForArg,
    keys,
    contracts
};
