# 4C Tezos smart contracts

This repository houses the `v0.0` Tezos smart contracts for the Cambridge
Centre for Carbon Credits.

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

# v1.0

In `v1.0` we intend to move to having a set of permissioned on-chain entities
who can hold and exchange the FA2 carbon credit tokens.

Why permissioned? There are requirements around what they can do with them (e.g
keeping them on Tezos, ensuring a % of secondary sales go to the original
projects/some other pot). These requirements will be determined by the
flexibility of agreements made with initial supply partners.

Our primary goal with v1.0 is to enable these entities to sell and (preferably)
auto-retire carbon credits to on-chain demand.  This enables many different
opportunities in the Tezos ecosystem:

* Exchanges that facilitate buying/selling between these entities
* Market makers that use metadata (permanence/additionality/leakage) from credits to rate and "bundle" credits to sell to other participants
* Providing the purchase+offset on-chain (they would provide an API for other smart contracts to call)
* Providing the purchase+offset to retail demand off-chain (e.g take fiat payments, bring that on-chain, purchase/retire offset and provide a display of this. There's value in making that process seamless and dealing with volatility).
* Integration with other demand sources, e.g Razer integrating in to the checkout process of the customers they provide payment processing for, then purchase+auto retiring and also hosting a page/email to show the offset)
* Wallet integration to show available offsets for purchase planning.
