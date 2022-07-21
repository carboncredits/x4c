import fetch from "node-fetch";

import { ContractStorage } from "../tzstats-client/types";

function withPromise<T>(fn: (v: void) => Promise<T>): Promise<T> {
    return new Promise(async (resolve, reject) => {
        try {
            const v = await fn ();
            resolve(v);
        } catch (error) {
            reject(error);
        }
    })
}

export default class Tzkt {
    private readonly BASE_URL: string;
    private readonly VERSION : string;

    constructor (base_url: string = "https://api.tzkt.io", version: string = "v1") {
        this.BASE_URL = base_url;
        this.VERSION = version
    }

    private buildEndpoint(endpoint: string, params?: URLSearchParams): string {
        const url = `${this.BASE_URL}/${this.VERSION}/${endpoint}`;
        return params ? `${url}?${params.toString()}` : url;
    }

    public getContractStorage(contractHash: string): Promise<ContractStorage> {
        return withPromise(async () => {
            const request = this.buildEndpoint(`contracts/${contractHash}/storage`);
            const response = await fetch(request);
            const json = await response.json();

            return { value: json, prim: undefined } as ContractStorage;
        })
    }

    public getBigMapValues(bigmapID: number): Promise<any> {
        return withPromise(async () => {
            // Remove inactive entries
            const params = new URLSearchParams({ active: "true" });
            const request = this.buildEndpoint(`bigmaps/${bigmapID}/keys`, params);
            const response = await fetch(request);
            const json = await response.json();
            // We make the keys look like what is returned by Tzstats
            const res = json.map((i : any) => ({
                ...i,
                key: [
                    i.key.kyc,
                    i.key.token.token_address,
                    i.key.token.token_id
                ]
            }))
            return res;
        })
    }
}