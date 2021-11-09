# X4C

This repository houses the smart contracts for the Cambridge Centre for Carbon Credits.

## Structure 
There are three primary contracts, which are:
* `x4c-project.mligo`
* `x4c-oracle.mligo`
* `x4c-market.mligo`

## Project Contract
The project contract allows anyone to create a project. The oracle contract will then verify the project is valid and allow it to mint tokens. As a project grows, project owners can add "zones" to their project, which represent a new token attached to their project. As before, these need to be approved by the oracle to be minted and traded on the marketplace.

The project contract is a standard FA2 contract with all the the standard entrypoints. Users and token holders can manage their tokens, i.e. with the `%transfer` or `%balance_of` entrypoints. This makes these carbon tokens composable with other on-chain applications.

## Oracle Contract
The oracle contract:
* Keeps a registry of valid coins, keeping the marketplace informed on which coins are allowed to be traded
* Gives the amount of valid coins a project owner can mint
* Gives the "bury" address and sends coins to be "buried"

## Marketplace 
The market contract is a dynamic marketplace that allows users to buy/sell carbon tokens in a variety of ways. Users can:
* Post tokens for sale at a fixed price 
* Sell tokens via an English auction 
* Sell tokens via a blind auction 
* Make a token owner an offer for their tokens 

For the auctions, the transaction can't be done automatically so there is a `%redeem` entrypoint that allows users to redeem the result of the auction, whether it be tokens they purchased or the payment for tokens sold.

The marketplace contract is custodial.