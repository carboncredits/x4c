import Tzkt from "./Tzkt";
import Tzstats from "../tzstats-client/Tzstats";

const client = new Tzkt("https://api.jakartanet.tzkt.io");

async function main () {
    const t = await client.getContractStorage("KT1TFHTEhcu55YedRiSTHa84BJZm6hCvi8cd")
    console.log(t);
    const v = await client.getBigMapValues((t.value as any).ledger);
    console.log(v);
}

const client2 = new Tzstats("https://api.jakarta.tzstats.com");

async function main2 () {
    const t = await client2.getContractStorage("KT1TFHTEhcu55YedRiSTHa84BJZm6hCvi8cd")
    console.log(t);
    const v = await client2.getBigMapValues((t.value as any).ledger);
    console.log(v);
}

async function run () {
    await main ();
    console.log("<><><><><><><><><><>");
    await main2 ();
}

run ();