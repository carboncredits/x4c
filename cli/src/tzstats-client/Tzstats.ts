import fetch from "node-fetch";

import { Account, Contract, ContractCalls, ContractStorage, IndexerStatus } from "./types";

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

export default class Tzstats {
    private readonly BASE_URL: string;

    constructor (base_url: string = "https://api.tzstats.com/") {
        this.BASE_URL = base_url;
    }

    private buildEndpoint(endpoint: string, params?: URLSearchParams): string {
        const url = `${this.BASE_URL}/${endpoint}`;
        return params ? `${url}?${params.toString()}` : url;
    }

    public getIndexerStatus(): Promise<IndexerStatus> {
        return withPromise(async () => {
            const request = this.buildEndpoint("/explorer/status");
            const response = await fetch(request);
            const json = await response.json();

            return json as IndexerStatus;
        })
    }

    public getContract(contractHash: string): Promise<Contract> {
        return withPromise(async () => {
            const request = this.buildEndpoint(`/explorer/contract/${contractHash}`);
            const response = await fetch(request);
            const json = await response.json();

            return {
                ...json,
                first_seen_time: new Date(json.first_seen_time),
                last_seen_time: new Date(json.last_seen_time),
            } as Contract;
        })
    }

    // Prim means the response will also contain the underlying Michelson primitives, by default it is false
    public getContractStorage(contractHash: string, prim?: boolean): Promise<ContractStorage> {
        return withPromise(async () => {
            const params = prim ? new URLSearchParams({ prim: "1" }) : undefined
            const request = this.buildEndpoint(`/explorer/contract/${contractHash}/storage`, params);
            const response = await fetch(request);
            const json = await response.json();

            return json as ContractStorage;
        })
    }

    // Prim means the response will also contain the underlying Michelson primitives, by default it is false
    public getContractCalls(contractHash: string, prim?: boolean): Promise<ContractCalls> {
        return withPromise(async () => {
            const params = prim ? new URLSearchParams({ prim: "1" }) : undefined
            const request = this.buildEndpoint(`/explorer/contract/${contractHash}/calls`, params);
            const response = await fetch(request);
            const json = await response.json();

            return json as ContractCalls;
        })
    }
    
    public getBigMapValues(bigmapID: number, prim?: boolean): Promise<any> {
        return withPromise(async () => {
            const params = prim ? new URLSearchParams({ prim: "1" }) : undefined
            const request = this.buildEndpoint(`/explorer/bigmap/${bigmapID}/values`, params);
            const response = await fetch(request);
            const json = await response.json();
            return json;
        })
    }

    public getAccount(accountHash: string): Promise<Account> {
        return withPromise(async () => {
            const request = this.buildEndpoint(`/explorer/account/${accountHash}`);
            const response = await fetch(request);
            const json = await response.json();
            return {
                ...json,
                first_seen_time: new Date(json.first_seen_time),
                last_seen_time: new Date(json.last_seen_time),
                first_in_time: new Date(json.first_in_time),
                first_out_time: new Date(json.first_out_time),
                last_in_time: new Date(json.last_in_time),
                last_out_time: new Date(json.last_out_time),
                delegated_since_time: json.delegated_since_time ? new Date(json.delegated_since_time) : undefined
            } as Account;
        })
    }
}