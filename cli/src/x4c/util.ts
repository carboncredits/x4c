import { char2Bytes, bytes2Char } from '@taquito/utils';
import { ContractStorage, Operation } from '../tzstats-client/types';

function stringToMichelsonBytes(arg: string): string {
    const bytes = char2Bytes(arg);
    const payloadBytes = '05' + '01' + (bytes.length / 2).toString(16).padStart(8, '0') + bytes;
    return payloadBytes
}

function michelsonBytesToString(arg: string): string {
    if (!arg.startsWith('0501')) {
        return arg
    }
    let hex = arg.slice(12);
    return bytes2Char(hex);
}

// A Generic client for interfacing with Tzstats or Tzkt
export interface GenericClient {
    getContractStorage(hash: string): Promise<ContractStorage>
    getOperation(opHash: string): Promise<Operation[]>
    getBigMapValues(id: number): any
}

export {
    stringToMichelsonBytes,
    michelsonBytesToString
}
