# X4C

This repository houses the smart contracts for the Cambridge Centre for Carbon Credits.

## Structure 
There are three primary contracts, which are:
* `x4c-directory.mligo`
* `x4c-governance.mligo`
* `x4c-oracle.mligo`

## Directory Contract
The directory contract is the permanent contract that will manage all future 4C smart contracts as they undergo upgrades. It functions as a proxy contract manager, managing upgrades by switching pointers and activating/deactivating proxy contracts. In this first version, the only proxy contracts are the governance and oracle contracts, but that could change in the future. The entrypoints of the directory contract can only be called by the governance contract, meaning that it is governed (and thus all upgrades are governed) entirely by governance.

## Governance Contract
The governance contract allows for members of governance to propose upgrades, including changes in how it governs/is governed. Members of governance can submit a proposal which is voted on and then executed. Upgrades happen automatically on-chain, are not centralized, and do not require users to do anything (such as move from one contract to another).

## Oracle Contract
The oracle contract:
* Allows anyone to create a project through the `%createProject` entrypoint
* Gives the amount of valid coins a project owner can mint
* Keeps a registry of valid coins, keeping the marketplace informed on which coins are allowed to be traded
* Can retire carbon tokens, keeping a record of which wallets have retired what tokens, in what quantity, and when.

This is the core contract of 4C, which keeps a record of all active projects and tokens, manages minting/retiring, and keeps track of agents that have retired tokens. It also exposes those records to anyone through contract views. In doing so, it makes available the essential data for marketplaces and other applications that can build off of 4C.