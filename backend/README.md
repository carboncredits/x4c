# x4c backend

This is an implementation of the X4C MVP backend in Go using the [tzgo](https://blockwatch.cc/tzgo) library. It contains two main components, the x4cli command line tools, and the x4c server that forms part of the live X4C system.

In the 4C production system it is assumed that work will be carried out in two distinct phases wrt blockchain activities:

* The FA2 and Custodian contracts will be managed manually using the `x4cli` command line tools. These will let you create the contracts, add any project information, mint tokens, etc. These will be done using sensitive wallets which should not ever need to go near a server used to host the rest of the service. These wallets will be used to authorize an operator wallet that has limited power to just retire certain credits as part of the live system.
* The retirements will happen using the server, which will be configured to use an operator wallet. This wallet should be based on an HSM such as a yubikey, so should the server be compromised the damage that can be done is limited.


## Command line tools

The `x4cli` tools are a simple way for you to interact with the 4C FA2 and Custodian contracts, without having to use `tezos-client`, where you'd need to manually read/write michelson primatives. `x4cli` does build upon `tezos-client`, it assumes that you've used that to set up your wallets, and will use/modify the `tezos-client` information (usually found in `$HOME/.tezos-client`). If you attempt to sign any operations using an address that doesn't have a secret key in the `tezos-client` data store, then it is assumed that you're using [Signatory](https://signatory.io), and in which case you must have `SIGNATORY_HOST` environmental variable configured.

By default `x4cli` will attempt to guess parameters such as the RPC server and Indexer URLs based on the settings for `tezos-client`. However, you can override this by setting the following environmental variables:

* TEZOS_RPC_HOST - the base URL of the Tezos RPC node to use
* TEZOS_INDEX_HOST - the base URL of the Tzkt indexer API
* SIGNATORY_HOST - the base URL of the signatory node to use

For an example of how the command line tool should be used please see either the root README.md or `integration_tests.sh`


## Server

The `server` binary is the part of the online 4C retirement system that interacts with the chain directly. It will use an indexer to work out current state, and it will talk to the chain to carry out token retirement on custodian contracts.

The server takes the following configuration options, all specified via enviromental variables:

* CUSTODIAN_OPERATOR - the address of a wallet to use for signing operations. There is no way to specify the secret key for the wallet, so this must be accessed via Signatory.
* TEZOS_RPC_HOST - the base URL of the Tezos RPC node to use
* TEZOS_INDEX_HOST - the base URL of the Tzkt indexer API
* TEZOS_INDEX_WEB - the base URL of the Tzkt human facing website (used in certain API responses)
* SIGNATORY_HOST - the base URL of the signatory node to use
