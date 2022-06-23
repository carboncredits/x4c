# X4C

This repository houses the smart contracts for the Cambridge Centre for Carbon Credits.

## Structure 
There are three primary contracts, which are:
* `fa2.mligo`
* `baker.mligo`
* `custodian.mligo`

## FA2
This is a standard FA2 contract which has a special `Retire` entrypoint specific to carbon credits.

## Custodian
This contract is a custodian ledger that allows a custodian to manage tokens on behalf of others.

## Baker
This contract will allow bakers to offset their own emissions.