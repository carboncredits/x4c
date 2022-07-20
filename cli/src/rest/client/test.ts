import X4CRest from "./X4CRest";

const client = new X4CRest("http://localhost:9000");

const main = async () => {
  const sources = await client.getCreditSources("KT1TFHTEhcu55YedRiSTHa84BJZm6hCvi8c");
  console.log(sources);
  const retire = await client.retireCredit(
    "KT1TFHTEhcu55YedRiSTHa84BJZm6hCvi8c",
    sources[0].tokenId,
    sources[0].minter,
    sources[0].kyc,
    42,
    "Offsetting travel"
  );
  console.log(retire);
}

main ()