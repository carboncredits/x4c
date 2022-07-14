import Tzstats from "./Tzstats";

const client = new Tzstats();

async function main () {
    await client.getIndexerStatus().then(i => {
        console.log(i);
    })

    await client.getContract("KT1Puc9St8wdNoGtLiD2WXaHbWU7styaxYhD").then(i => {
        console.log(i);
    })

    await client.getContractStorage("KT1Puc9St8wdNoGtLiD2WXaHbWU7styaxYhD", true).then(i => {
        console.log(i);
    })

    await client.getAccount("tz1Z7eWGw18LqUgRqmDqNZFQx7f8GEHXRfT8").then(i => {
        console.log(i);
    })
}

main ()