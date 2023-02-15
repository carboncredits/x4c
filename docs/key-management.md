X4C Key Management documentation

# Introduction

This document outlines what Tezos wallets are required in the X4C system, what authority they will have, and how the keys should be managed in any deployment.


## Terminology

This section covers the terminology we’ll assume through the remainder of the document.

### Public/Private Key Signing

The blockchain works on public-key cryptography, where an encryption key comes in two halves: the public key that anyone can know, and the private key that only the key owner knows. Digital signing of data works by generating an encrypted digest of the data in question using the private key, which anyone can verify by decrypting the digest with the public key and comparing it with their own calculated digest. If they match we know that only the person with the private key could have generated the encrypted digest.

### Wallet

The Tezos term for a public/private key pair used for signing operations. The name wallet implies storage, but in fact it is just a key pair, and then funds and tokens stores on the blockchain and associated to that key pair.

Transactions on the blockchain are verified as being on behalf of a particular wallet by having the wallet owner use the private key pair to sign the transaction. This means that in a blockchain system, the ability to carry out actions is based on access to the private key of a key-pair, which is why it's vitally important to restrict access to the private key.

### Hot and Cold Wallets

A wallet is said to be "hot" if it's being used in a computer, and "cold" if it's being stored offline and so not digitally accessible.


### Hardware Security Module (HSM)

To sign data on a particular computer you need access on that computer to the private key of a key-pair. This means that if a computer is compromised then the attacker can now spoof being the owner of the key-pair or wallet because they have access to the private key. Worse, because digital data is inherently copyable, the attacker can take the private-key off the compromised computer to their own computer and forever more pretend to be that wallet, even if their access to the computer is later revoked.

An HSM is a hardware device that you plug into a computer in order to solve the second problem described above. You can install your private-key into an HSM and then delete the private key from that computer, and from then on ask the HSM to sign things for you. An HSM will never give out the stored private key, it can only be used to sign things with that key - that means an attacker can never take a copy of the private key. They can still ask the HSM to sign things whilst they have access to the server, but once the attack is discovered and revoked they can no longer continue to sign things.


### FA2 Contracts

The X4C contract is based on a standard multi-asset contract definition under Tezos, known in the community as a [FA2](https://gitlab.com/tezos/tzip/-/blob/master/proposals/tzip-12/tzip-12.md) contract. An FA2 contract lets you define multiple asset types, referenced by an ID, and a count of those assets, and assign a number of them to different owners. These assets are generally known as tokens.

There are some standard terms used for the different entities involved in the making and ownership of tokens. By entities we mean addressable entities in the Tezos system: these may be humans using a wallet, or another contract - both of these have a Tezos address and therefore both can be an entity as far as we are concerned in this discussion.

The main ones are:

* **Oracle**: This is the effective owner of the FA2 contract, as recorded in the contract instance. For most contract calls only the oracle can invoke them.

* **Token owner**: An entity who actually has some tokens assigned to them.

* **Operator**: This is a delegated role, recorded in the FA2 contract instance. An oracle may add operators to carry out certain limited duties on a token owner's behalf on a specific owner (as there's nothing to stop a token owner owning many different token types within the same contract).


To reiterate, all three roles may be either human controlled wallets or other Tezos contracts.


## Related work

The other comparison here is with [X.509 public key management](https://en.wikipedia.org/wiki/X.509), which is both used for HTTPS security management and enterprise security management. We will not cover all of X.509 here, as it’s a big topic, but the part that is relevant is how the trust hierarchy works.

In X.509 key management you end up with a tree of certificates. At the root of the tree is a super important certificate that is known to be trusted. This key can then be used to sign other certificates as a way of delegating trust. These certificates are the ones actually used, and the master super important key is kept offline typically. These child certificates have a shorter shelf life (they expire after say 30 days or a year, whereas the root cert will be set to last for a decade or so) and have less scope of trust (e.g., restricted to a single domain for a website certificate), but because of these restrictions they’re allowed to be online and be usable, whereas the root certificate is so important it’s not allowed to be online most of the time.

This is a gross simplification, but the important take away is that the keys that form your root of trust should have a little access as possible, and you use delegation of limited scope to other keys that can be online with lower risk of bad things happening when eventually one is compromised (I’m ignoring revocation lists etc. as there’s no analogous part of that in the Tezos world).

In this sense, the operator mechanism in a Tezos FA2 contract is a simple version of this standard mechanism: it allows one wallet to be used infrequently and kept mostly offline (the Oracle) and then for more frequent operations a limited scope wallet may be used (the Operator).


# X4C Contract Overview

In this section we describe how all these parts fit together in the initial

## Contract use

In the 4C Tezos contract system we have two contract types, the FA2 token issuing contract, and the custodian token management contract. Tokens in this will related to some amount of CO2 offset typically, enabling you to buy carbon credits ahead of time, and then later retire them as offsets are needed.

There will typically be one FA2 contract per institute managing credits being added to the chain, with each carbon credit generating project being in effect a new asset-type, and the credits within that project being a token (e.g., 1 token represents 1kg of CO2).

Once the credits have been registered, people can acquire them. The mechanism for any exchange to pay for the credits etc. is not part of the X4C contract - that happens outside, and when some agreement is reached a number of project credits, or tokens for a particular asset, are transferred to the buyer.

The buyer may assign the tokens to a wallet directly, or more likely in the X4C context, they will use an X4C custodian contract. Using a custodian contract to manage tokens you own confers two benefits:

1. You can divide the tokens you've acquired between multiple off-chain entities (represented as byte strings in the contract). For example, a large enterprise could buy the credits and then assign them to different departments within that organisation. Doing so with a custodian contract means the different departments do not need their own wallets, and all the retirements will be still credited to the enterprise, but there will be some trail of how they were used on the chain.
1. The custodian contract makes it easier to dominate a delegate wallet, which is useful for security reasons, and discussed in more detail below. In theory you can use operators on the FA2 contract directly, but that requires approval of the FA2 operator each time, so its easier to do this on a custodian contract you have ownership of.

Carbon credits do not tend to be held on to, like other assets, rather they are "consumed" when the holder emits some carbon, thus being used to offset those emissions. When this happens the tokens are "retired", which in effect deletes them from both the custodian contract (if one is being used) and from the originating FA2 contract. Although the token is deleted, the tokens lifecycle will have been recorded in the blockchain, providing traceability that the institution bought and retired the carbon credit.


## FA2 Entrypoints

Here are a list of the major tasks within the X4C system, which translate to endpoint calls on the contracts, and who is responsible for initiating them.

### Add Token

* Initiated by: FA2 Oracle
* Description: When a project is registered, it has to be given a unique ID to identify it's tokens; this call adds the ID to the FA2 contract ledger.

### Mint Token

* Initiated by: FA2 Oracle
* Description: When a project generates new credits, these must first be generated in the FA2 contract as tokens. Initially minted tokes are owned by the contract oracle.

### Token Transfer

* Initiated by: Token owner
* Description: At some point an entity will want to acquire tokens, and so the FA2 oracle will transfer them to that organisation, or to their custodian contract.

### Update Operators

* Initiated by: FA2 Oracle
* Description: Allows the adding or removing of another entity to be designated as having the ability to transfer a particular set of tokens.

### Retire

* Initiated by: Token owner
* Description: removes a specified number of tokens from the owner's ledger entry, effectively deleting them, signifying carbon credits being retired.


### Update contract metadata

* Initiated by: FA2 Oracle
* Description: Standard FA2 call that lets the oracle set some metadata about the contract, which is then shown in indexers. Not used in X4C workflow.


### Update Oracle
* Initiated by: FA2 Oracle
* Description: Lets the current Oracle nominate a new entity to be the owner of the FA2 contract. Not used in X4C workflow.


### Balance of
* Initiated By: Anyone
* Description: returns the balance for a token. Superseded by the view, but kept for legacy reasons. Not used in the X4C workflow.


## Custodian Entrypoints

### Internal Mint

* Initiated by: Custodian owner
* Description: If the token owner is using a custodian contract to manage their tokens, then they need to manually synchronise the custodian contract with the main FA2 contract to ensure tokens they own on the FA2 contract's internal ledger appear on the custodian contract's ledger.


### Internal Transfer

* Initiated by: Custodian owner
* Description: This updates the custodian contract's internal ledger to divide the tokens from a given FA2 contract an off-chain entity.


### Update Operators

* Initiated by: Custodian owner
* Description: Allows the adding or removing of another entity to be designated as having the ability to retire a particular set of tokens for a particular off-chain entity.


### Retire

* Initiated by: Custodian owner OR Custodian operator
* Description: Removes tokens from the custodian ledger and then calls the FA2 contract to retire the contracts properly.


### External Transfer

* Initiated by: Custodian owner
* Description: Is used to assign tokens to some other entity, removing them from the custodian contract, without retiring them. Not currently used in the X4C system.



# X4C Initial Production Configuration

As outlined in the introduction section, key security is vital in a blockchain system, as once a private key is known, the owner can be spoofed. For a working system there will have to be some time spent with keys being hot, but that should be minimised as much as possible. To understand how to achieve that, we first need to examine how X4C is expected to be deployed.

## Carbon Credit Token Lifecycle

In a standard X4C system it is expected that tokens will be acquired in bulk batches ahead of time, and retired as carbon offsets are consumed on flights etc. made by the organisation, perhaps via some web-service as part of the travel booking. The rough cycle is:

1. A project has some carbon sinking ability that it wants to offer as offsets. This project is added to the FA2 contract.
2. As offsets are generated, tokens are added to the FA2 token. Whilst this is an incremental process, in practice we anticipate this will be done in bulk periodically.
3. An organisation will acquire tokens, with the FA2 owner assigning them to the organisations custodian contract. Again, this is expected to be a periodic bulk purchase initially, similar to how offsets are bought today.
4. The organisation will then synchronise their custodian contract with the FA2 contract, so the new credits are now on the ledger in the custodian contract.
5. The credits will then most likely be divided between off-chain entities at the same time.
6. As the organisation goes about its business, carbon emmisions will be gradually generated, and as part of that process, tokens will be retired.

In this workflow, it's only the last stage that is a continual process, with all the other stages effectively being a manual batch operation done periodically by a human.

| Batch | Continuous |
|---|---|
| FA2 Mint | FA2 Retire |
| FA2 Transfer | Custodian Retire |
| FA2 Update Operators | |
| FA2 Add Token | |
| Custodian Internal Mint | |
| Custorian Internal Transfer | |
| Custorian Update Operators | |


## Key Management Implications

For those operations that need to be continuously available, we will need a hot wallet to be accessible on a server. For all other operations the keys should be managed by a human using a  cold wallet that is only brought online briefly to carry out specific actions like registering projects, minting new tokens, and transferring tokens to organisations that acquire them, and the security can be further enhanced using a hardware backed wallet like [Ledger](https://www.ledger.com/tezos-wallet) or [Trezor](https://trezor.io).

However the hot wallet used to power the server is a significant attack liability:

1. No wallets with any sort of significant power should be stored on a publicly reachable server (so neither FA2 Oracle or Custodian Owner).
2. No private-keys should be left on any publicly reachable server.

Note that by "publicly reachable" I mean any server that your web service connects to, even if that machine isn't on the public facing Internet directly. We have to assume that any node in a cluster that makes up a web-service can be reachable once compromised by an attacker. If your private-keys are on a machine that only response to local network requests from a publicly addressable we have to assume that a determined attacker will compromise the first machine to then reach the second machine.

The solution to this is then twofold:

1. We should use operator wallets for any contract endpoints that require a hot wallet as part of the deployment.
2. We should use an HSM to store the private-key on the server, so as to limit the impact of an attack.

Thus in the X4C system, the hot/cold wallet division would become:

| Key | Type |
|---|---|
| FA2 Owner | Cold |
| Custodian Owner | Cold |
| Custodian Operator | Hot |


