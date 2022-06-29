# 4C

This repository houses the `v0.0` smart contracts for the Cambridge Centre for Carbon Credits.

# v0.0

This is a minimal implementation designed to enable minting, retirement and custodial services
of tokenised carbon credits. It will be used to manage and account for the first 4C supply and demand transactions as well as the building of integrations with other on-chain demand sources (e.g Kanvas transaction offsets). Due to initial supply purchases being at pre-agreed prices, there's no market mechanism at present.

This initial version consists of a mostly-standard `FA2` implementation with an additional `%retire` entrypoint that has a metadata parameter for retirement purposes. It also has a `custodian` contract that allows holding these FA2 tokens on behalf of an off-chain entity, moving these tokens between those entities and moving to/from the custodian to on-chain wallets/other custodians.

It is intended that the metadata from the `%retire` entrypoint can be indexed and used to provide
information as to the _use_ of carbon offsets. This enables transparency that doesn't exist at present in the traditional voltunary carbon market.

## Structure
There are two primary contracts, which are:
* `fa2.mligo`
* `custodian.mligo`

### FA2
This is a standard FA2 contract which has a special `%retire` entrypoint specific to carbon credits. The entrypoint takes as input metadata, which can be populated to specify data relevant to the offset (e.g. who is offsetting and for what purpose). This data is not explicitly stored on-chain, but since it is recorded in the transaction metadata it still serves as a trusted record for carbon offset activity.

### Custodian
This contract is a custodian ledger that allows a custodian to manage tokens on behalf of others, kept track of as KYC entities (in `bytes`). This is a general purpose carbon token custodian contract, in that it can manage funds of any token contract (or set of token contracts) in which it has a balance. It faithfully keeps track of balances and has entrypoints to manage an internal ledger as well as emit external transfer transactions to the token contract.

The `%internal_mint` and `%internal_transfer` entrypoints manage the internal custodian ledger, where the former fetches and updates the custodian's balance in a particular token contract, and the latter is a transfer on the internal ledger. The `%external_transfer` and `%retire` emit, respectively, transfer and retire contract calls to the token contract.

# Future plans

In `v1.0` we intend to move to having a set of permissioned on-chain entities who can hold and exchange the FA2 carbon credit tokens. There are requirements around what they can do with them (e.g keeping them on Tezos, ensuring a % of secondary sales go to the original projects/some other pot). These requirements will be determined by the flexibility of agreements made with initial supply partners. It is intended that these entities can sell and auto-retire carbon credits to on-chain and off-chain demand. This enables many different opportunities in the ecosystem:

* Exchanges that facilitate buying/selling between these entities
* Market makers that use metadata from credits to rate and "bundle" credits to sell to other participants
* Providing the purchase+offset on-chain (they would provide an API for other smart contracts to call)
* Providing the purchase+offset to retail demand off-chain (e.g take fiat payments, bring that on-chain, purchase/retire offset and provide a display of this. There's value in making that process seamless and dealing with volatility).
* Integration with other demand sources, e.g Razer integrating in to the checkout process of the customers they provide payment processing for, then purchase+auto retiring and also hosting a page/email to show the offset)