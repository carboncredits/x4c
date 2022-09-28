# 4C Tezos smart contracts

This repository houses the `v0.0` Tezos smart contracts for the Cambridge
Centre for Carbon Credits.

Note that this repository includes submodules, and so should be checked out using either `git clone --recursive` or updated with `git submodule update --init --recursive`.

**Warning: The contracts have only been deployed on testnets at present,
and are still being audited/tested. Not for live deployment until later
in the year.**

# v0.0

This is a minimal implementation designed to enable minting, retirement and
custodial services of tokenised carbon credits. It will be used to manage and
account for the first 4C supply and demand transactions as well as the building
of integrations with other on-chain demand sources (e.g Kanvas transaction
offsets). Due to initial supply purchases being at pre-agreed prices, there's
no market mechanism at present.

**FA2:** This version consists of a mostly-standard `FA2` implementation with an
additional `%retire` entrypoint that has a metadata parameter for retirement
purposes. It also has a `custodian` contract that allows holding these FA2
tokens on behalf of an off-chain entity, moving these tokens between those
entities and moving to/from the custodian to on-chain wallets/other custodians.

**Token:** Although we have one token contract, each project is associated a
separate token id that tracks the project type and geographical coordinates.
Tokens are fungible within each project, and we then have pricing strategies
to make them exchangeable _across_ token ids. For example by adjusting for
one deforestation project having a lower permanence than another one in a
different country, we can adjust the price appropriately to allow both projects
to be purchased as part of a carbon offset portfolio.  More details on the
quantitative pricing scheme ('PACT', for Permanent Additional Carbon Tonnes)
are available on request. This can eventually become a dex, but is not
currently implemented on-chain.

**Continuous retirement:** It is intended that the metadata from the `%retire`
entrypoint can be indexed and used to provide information as to the _use_ of
carbon offsets. This enables transparency that doesn't exist at present in the
traditional voltunary carbon market.  This is also a cheap operation to run
on-chain (we do not issue a transferable retirement token) in order to
encourage frequent retirement transactions for a real-time tally.

## Structure
There are two primary contracts, which are:
* `fa2.mligo`
* `custodian.mligo`

### FA2
This is a standard FA2 contract which has a special `%retire` entrypoint
specific to carbon credits. The entrypoint takes as input metadata, which can
be populated to specify data relevant to the offset (e.g. who is offsetting and
for what purpose). This data is not explicitly stored on-chain, but since it is
recorded in the transaction metadata it still serves as a trusted record for
carbon offset activity.

### Custodian
This contract is a custodian ledger that allows a custodian to manage tokens on
behalf of others, kept track of as KYC entities (in `bytes`). This is a general
purpose carbon token custodian contract, in that it can manage funds of any
token contract (or set of token contracts) in which it has a balance. It
faithfully keeps track of balances and has entrypoints to manage an internal
ledger as well as emit external transfer transactions to the token contract.

The `%internal_mint` and `%internal_transfer` entrypoints manage the internal
custodian ledger, where the former fetches and updates the custodian's balance
in a particular token contract, and the latter is a transfer on the internal
ledger. The `%external_transfer` and `%retire` emit, respectively, transfer and
retire contract calls to the token contract.

# Example usage

These are the steps required to instantiate the basic contract pair on a testnet.

## Prerequisites

First make sure you have [tezos-client](https://assets.tqtezos.com/docs/setup/1-tezos-client/) and the [x4c CLI](cli/) tools installed.

Next ensure you have the contracts up to date. You’ll need [ligo tools](https://ligolang.org/docs/intro/installation) installed, or you'll want to use Docker (which is what ligo generally recommend). To have the Makefile for compiling the contracts use docker set the following environment variable:

```
$ export USE_DOCKER=yes
```

Then run make:

```
$ cd path_to_x4c_repo
$ make
```

This should give you fa2.tz and custodian.tz in the build/ directory.

Finally you'll want to select a [test network](https://teztnets.xyz) on which to instantiate the contracts. For the 4C end-to-end experience you'll need to ensure you have the following endpoints available on the test network:

* An Tezos node RPC endpoint - e.g., https://rpc.kathmandunet.teztnets.xyz
* An Indexer RPC endpoint - e.g., https://api.kathmandu.tzstats.com
* An Indexer human frontend - e.g., https://kathmandu.tzstats.com

When using a test net tezos-client will report that you're not on mainnet on every command invocation, so you may wish to set the following environmental variable to prevent that:

```
$ export TEZOS_CLIENT_UNSAFE_DISABLE_DISCLAIMER=yes
```

## Steps

### Set up an admin wallet

Not strictly necessary, but I find it makes testing easier - you should create a wallet for you as the admin and ensure it has some tez associated with it. In this example we're using [Kathmanduanet](https://teztnets.xyz/kathmandunet-about).

If you have an old tezos-client state, you may wish to backup your ~/.tezos-client folder. You can then reset the state there if you're not already on kathmandunet using:

```
$ tezos-client config reset
```

Set tezos-client to use the right test network:

```
$ tezos-client --endpoint https://rpc.kathmandunet.teztnets.xyz config update

```

Now you want to set up a new wallet and get some tez on that. First create the wallet:

```
$ tezos-client gen keys facetwallet
$ tezos-client get balance for facetwallet
0 ꜩ
$ x4c info
Alias           Hash                                   Contract type   Default
 facetwallet    tz1cyDKwRw1CAT1dw7B95eBPqUq456rW6Gsw   Wallet
```

Then go to https://faucet.kathmandunet.teztnets.xyz and request tez for the wallet’s hash. Once you've done that you should hopefully find you now have some tez:

```
$ tezos-client get balance for facetwallet
6001 ꜩ
```

Note that it may take a little time for the transaction to propagate, so you may initially see a zero balance, but just try again in a minute.

### Set up X4C actors wallets

Now we need to create three wallets for the different actors in the X4C contract world. You can have more, but three is the recommended minimum:

1. A wallet for the owner of the FA2 contract
2. A wallet for the owner of the custodian contract
3. A wallet for the online operator of the custodian contract

The first two wallets will generally live not on a live server, but out of necessity the final wallet will be one that has to be online to let API calls be accessed from the 4C web frontend. It is recommended that the other two wallets are not put on a publically accessible server.

We can create these wallets and assign them some tez so that they can do things:

```
$ tezos-client gen keys FA2Owner
$ tezos-client transfer 1000 from facetwallet to FA2Owner --burn-cap 0.1
...
$ tezos-client gen keys CustodianOwner
$ tezos-client transfer 1000 from facetwallet to CustodianOwner --burn-cap 0.1
...
$ tezos-client gen keys CustodianOperator
$ tezos-client transfer 1000 from facetwallet to CustodianOperator --burn-cap 0.1
...
```

Note that in practice you would not use a local wallet for the operator - you'd want to use a remote signer that is based on a hardware security key. See the section [Deployment security](#deployment-security) for details below.

### Originate the contracts

You can use the x4c tools to instantiate the contracts. First do the FA2 contract thus:

```
$ x4c fa2 originate FA2Contract build/fa2.tz FA2Owner
Contract originated as KT1HrP3bxARDNWxGyEPtx3LprzUQczg8u19a
```

and then a custodian contract:

```
$ x4c custodian originate CustodianContract build/custodian.tz CustodianOwner
Contract originated as KT1AoLsWX28kH4YhyCKm2g9wGUJGgud8Mkp3
```

In practice there may be many custodians, but few FA2s (citation needed).

### Create some tokens

Now we need to add a token definition and then mint some actual tokens. There would be a token per project ideally.

```
$ x4c fa2 add_token FA2Owner 123 "My project" "http://project.url" FA2Contract
Adding token...
Awaiting for onwEvkpVH19BPzoZdgHNqLQnD5k3AreZchXw5HSXdadDcEEUdBb to be confirmed...
Operation injected: https://rpc.kathmandunet.teztnets.xyz/onwEvkpVH19BPzoZdgHNqLQnD5k3AreZchXw5HSXdadDcEEUdBb

$ x4c fa2 mint FA2Owner CustodianContract 123 1000 FA2Contract
Minting tokens...
Awaiting for ooowBFJwhYMLcBCTeycxa9w7BWE3fbUPMraEAsrVW2LgxStqQ2P to be confirmed...
Operation injected: https://rpc.kathmandunet.teztnets.xyz/ooowBFJwhYMLcBCTeycxa9w7BWE3fbUPMraEAsrVW2LgxStqQ2P
```

We need then to sync the custodian contract with the FA2 contract:

```
$ x4c custodian internal_mint CustodianOwner CustodianContract FA2Contract 123
Syncing tokens...
Awaiting for opViJhWJz3HBzS2K5x3hf5BaXWpbmrD5yLkYd2y55YxcCznZAbJ to be confirmed...
Operation injected: https://rpc.kathmandunet.teztnets.xyz/opViJhWJz3HBzS2K5x3hf5BaXWpbmrD5yLkYd2y55YxcCznZAbJ
```

Finally, the custodian is holding tokens for off-chain entities that aren't expected to hold their own wallets. By default the internal_mint call to the custodian has "self" holding the tokens, but in practice you'd then assign them to others:

```
$ x4c custodian internal_transfer CustodianOwner CustodianContract FA2Contract 123 500 "self" "example corp"
Syncing tokens...
Awaiting for opCPgnfteYVeKNL2gNo75h9WzGJaS2MAmPbK9DepPegu7FDsXxH to be confirmed...
Operation injected: https://rpc.kathmandunet.teztnets.xyz/opCPgnfteYVeKNL2gNo75h9WzGJaS2MAmPbK9DepPegu7FDsXxH```

$ x4c custodian internal_transfer CustodianOwner CustodianContract FA2Contract 123 500 "self" "other org"
Syncing tokens...
Awaiting for ooatdoMAwHRNwTJ7trxd5G8m391yDFaWkHSddpT8JwCXmeZu7HY to be confirmed...
Operation injected: https://rpc.kathmandunet.teztnets.xyz/ooatdoMAwHRNwTJ7trxd5G8m391yDFaWkHSddpT8JwCXmeZu7HY
```

### Delegate retirement authority

To avoid having the custodian contract's owner's wallet online, we should delegate responsibility for retiring the credits to one or more operators. In this example I'm going to use a single operator wallet, but you would probably use one per off-chain client. The operator's wallet can then be held on a public facing server without fear that if it is compromised all tokens held by the custodian contract can be drained.

```
$ x4c custodian add_operator CustodianOwner CustodianContract CustodianOperator 123 "other org"
Adding operator...
Awaiting for oow5qgodszwHSo17eXN2XdcumDpMMsbDeSuYVCVCnDEyDAghVK5 to be confirmed...
Operation injected: https://rpc.kathmandunet.teztnets.xyz/oow5qgodszwHSo17eXN2XdcumDpMMsbDeSuYVCVCnDEyDAghVK5
```

Once this is done the CustodianOperator wallet can only call retire or internal_transfer on the CustodianContract for the tokens of ID 123 that have been assigned to "other org".

## Deployment security

In the above test setup we have three addresses in play. The first two are used offline to manage tokens: the FA2 owner can add projects, mint tokens, and then assign them to a custodian, and the custodian owner can assign their tokens to different internal "users". Then there is the custodian operator contract, which is the token that is used online to retire requests based on imagined API calls. Whilst in the demo script above we use tezos-client to manage this wallet, in practice you should not do that, as that requires the wallet's secret key to be stored online.

Instead, in this setup a remote signature should be configured that uses something like [Signatory.io](https://signatory.io/) to provide access to a key managed via an HSM. The x4c library will assume that any addresses found in the .tezos-client library that don't have a secret key configured are remote managed, so you can simply add them as follows:

```
$ tezos-client add address CustodianOperator tz1XnDJdXQLMV22chvL9Vpvbskcwyysn8t4z
$ x4c info
Alias                 Hash                                   Contract type   Default
 CustodianOperator    tz1XnDJdXQLMV22chvL9Vpvbskcwyysn8t4z   Remote
```

An example use case of this can be seen in the integration tests shell script in the cli directory.
