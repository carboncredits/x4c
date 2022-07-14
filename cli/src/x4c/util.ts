import { char2Bytes } from '@taquito/utils';

function stringToMichelsonBytes(arg: string): string {
    const bytes = char2Bytes(arg);
    const payloadBytes = '05' + '01' + (bytes.length / 2).toString(16).padStart(8, '0') + bytes;
    console.log(payloadBytes);
    return payloadBytes
}

export {
    stringToMichelsonBytes
}
