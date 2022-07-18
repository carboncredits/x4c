import X4CRest from "./X4CRest";

const client = new X4CRest("http://localhost:9000");

const main = async () => {
  const sources = await client.getCreditSources();
  console.log(sources);
  const retire = await client.retireCredit(sources[0].uid);
  console.log(retire);
}

main ()