import fetch from 'node-fetch'
import { CreditSource, CreditRetireRequest, CreditRetireResponse } from "../common";

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

export default class X4CRest {
    private BASE_URL: string;

    constructor (url: string) {
        this.BASE_URL = url;
    }

    private buildEndpoint(endpoint: string, params?: URLSearchParams): string {
        const url = `${this.BASE_URL}/${endpoint}`;
        return params ? `${url}?${params.toString()}` : url;
    }

    public getCreditSources(contractPublichHash: string) {
        return withPromise(async () => {
            const request = this.buildEndpoint("credit/sources/" + contractPublichHash);
            const response = await fetch(request);
            const json = await response.json();
            return json.data as CreditSource[];
        })
    }

    public retireCredit(
        contractPublichHash: string,
        tokenId: number,
        minter: string,
        kyc: string,
        amount: number,
        reason: string
    ) {
        const body: CreditRetireRequest = {
            tokenId: tokenId,
            minter: minter,
            reason: reason,
            amount: amount,
            kyc: kyc
        }
        
        return withPromise(async () => {
            const request = this.buildEndpoint(`retire/${contractPublichHash}`);
            const response = await fetch(request, { 
                method: "POST",
                body: JSON.stringify(body),
                headers: { "Content-Type": "application/json" } 
            });
            const json = await response.json();
            return json.data as CreditRetireResponse;
        })
    }
}
