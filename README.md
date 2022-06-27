# 4C

This repository houses the `v0.0` smart contracts for the Cambridge Centre for Carbon Credits.

This initial version consists of a mostly-standard `FA2` implementation with an additional `%retire` entrypoint that has a metadata parameter for retirement purposes. It also has a `custodian` contract that allows holding these FA2 tokens on behalf of an off-chain entity, moving these tokens between those entities and moving to/from the custodian to on-chain wallets/other custodians.

These initial contracts are fairly restricted in use, though in future contracts we will open up the `retire` functionality more broadly. The Uuniversity of Cambridge will do their accounting for offsets using these contracts. These contracts can also integrate with Kanvas. There's no market mechanism at this point - there's none needed for the university's offsets and for Kanvas we'd need to agree a price for certain supply beforehand.

## Structure 
There are two primary contracts, which are:
* `fa2.mligo`
* `custodian.mligo`

### FA2
This is a standard FA2 contract which has a special `%retire` entrypoint specific to carbon credits. The entrypoint takes as input metadata, which can be populated to specify data relevant to the offset (e.g. who is offsetting and for what purpose). This data is not explicitly stored on-chain, but since it is recorded in the transaction metadata it still serves as a good record for carbon offset activity.

### Custodian
This contract is a custodian ledger that allows a custodian to manage tokens on behalf of others, kept track of as KYC entities (in `bytes`). This is a general purpose carbon token custodian contract, in that it can manage funds of any token contract (or set of token contracts) in which it has a balance. It faithfully keeps track of balances and has entrypoints to manage an internal ledger as well as emit external transfer transactions to the token contract.

The `%internal_mint` and `%internal_transfer` entrypoints manage the internal custodian ledger, where the former fetches and updates the custodian's balance in a particular token contract, and the latter is a transfer on the internal ledger. The `%external_transfer` and `%retire` emit, respectively, transfer and retire contract calls to the token contract.