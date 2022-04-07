# Markets

This repository holds example marketplaces that could be deployed to manage carbon tokens. These are not part of 4C. The two examples are the `x4c-market` contract and the `x4c-rpmm` contract.

## Market Contract
The market contract is a marketplace that allows users to buy/sell carbon tokens in a variety of ways. Users can:
* Post tokens for sale at a fixed price 
* Sell tokens via an English auction 
* Sell tokens via a blind auction 
* Make a token owner an offer for their tokens 

For the auctions, the transaction can't be done automatically so there is a `%redeem` entrypoint that allows users to redeem the result of the auction, whether it be tokens they purchased or the payment for tokens sold.

The market contract is custodial.

## RPMM Contract

The RPMM is a novel market-making mechanism designed specifically for pooling and trading families of semi-fungible tokens, such as carbon tokens. It is meant to address price discovery as well as deep liquidity of carbon tokens on-chain.