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

In the 4C Tezos contract system we have two contract types, the FA2 token issuing contract, and an optional custodian token management contract. Tokens in this will related to some amount of CO2 offset typically, enabling you to buy carbon credits ahead of time, and then later retire them as offsets are needed.

The FA2 contract will be managed by an organisation that is brokering carbon credits onto the blockchain. They are responsible for working with project that generate carbon credits, and creating a new "asset" (aka, token type) per project within their FA2 contract's ledger, giving it a numerical ID, and then "minting" tokens within that contract so that there is a record of how many credits have been generated by that project.

```
┌───────── Broker 1 ─────────────────┐     ┌─────────────────────────────────────────── Institution 42 ───────┐
│                                    │     │                                                                  │
│      ┌─────────── Broker FA2 ────┐ │     │   ┌─ Inst42 Custodian ──────────────┐                            │
│      │                           │ │     │   │                                 │    ┌──────────────────┐    │
│      │  ┌──────┬───────┬───────┐ │ │     │   │ ┌──────┬─────┬───────┬────────┐ │    │                  │    │
│      │  │Token │Amount │ Owner │ │ │     │   │ │Issuer│Token│Amount │  KYC   │ │    │      Dept A      │    │
│      │  ├──────┼───────┼───────┤ │ │     │   │ ├──────┼─────┼───────┼────────┤ │    │                  │    │
│      │  │ 1000 │ 34234 │ I42C  ◀─┼─┼─────┼─┬─┼─▶  B1  │1000 │ 23133 │ Dept A │ │    └──────────────────┘    │
│      │  ├──────┼───────┼───────┤ │ │     │ │ │ ├──────┼─────┼───────┼────────┤ │                            │
│      │  │ 1001 │ 2133  │  ...  │ │ │     │ └─┼─▶  B1  │1000 │ 11101 │ Dept B │ │    ┌──────────────────┐    │
│      │  └──────┴───────┴───────┘ │ │     │   │ └──────┴─────┴───────┴────────┘ │    │                  │    │
│      │                           │ │     │   │                                 │    │      Dept B      │    │
│      │                           │ │     │   │                                 │    │                  │    │
│      │                           │ │     │   │                                 │    └──────────────────┘    │
│      │                           │ │     │   │                                 │                            │
│      │                           │ │     │   │                                 │                            │
│      │                           │ │     │   │                                 │                            │
│      │                           │ │     │   │                                 │                            │
│      │                           │ │     │   │                                 │                            │
│      └───────────────────────────┘ │     │   └─────────────────────────────────┘                            │
└────────────────────────────────────┘     └──────────────────────────────────────────────────────────────────┘
```

Once the credits have been registered, other entities can acquire them, be it individuals or oranisations (we tend to focus on the later user case in this document, as it's more complicated). The mechanism for any exchange to pay for the credits etc. is not part of the X4C contract - that happens outside, and when some agreement is reached a number of project credits, or tokens for a particular asset, are noted as belonging to that entity - another entry in the FA2 contract's ledger.

All of this is thus far very standard Tezos FA2 contract behaviour. The first place X4C starts to diverge is that to help the buyer manage tokens, rather than the purchased tokens being owned by a wallet directly, they will typically go to a Custodian contract. created and owned by the purchaser of the credits. Using a custodian contract to manage tokens you own confers two benefits:

1. You can divide the tokens you've acquired between multiple off-chain entities, represented as byte strings in the contract, without those entities needing their own wallets. For example, a large enterprise could buy the credits and then assign them to different departments within that organisation. Doing so with a custodian contract means the different departments do not need their own wallets, and all the retirements will be still credited to the enterprise, but there will be some trail of how they were used on the chain.
1. The custodian contract makes it easier to nominate a delegate wallet that can manage a subset of the tokens tracked by that Custodian contract, which is useful for security reasons, and discussed in more detail below. In theory you can use operators on the FA2 contract directly, but that requires approval of the FA2 operator each time, so its easier to do this on a custodian contract you have ownership of.

The second way in which the X4C contract differs from a typical FA2 contract is that tokens will regularly be removed from the pool. Carbon credits do not tend to be held on to, like other assets, rather they are consumed when the holder emits some carbon, thus being used to offset those emissions. When this happens the tokens are "retired", which in effect deletes them from both the custodian contract (if one is being used) and from the originating FA2 contract. Although the token is deleted and thus can never be re-used or transferred, the token's lifecycle will have been recorded in the blockchain, providing traceability that the institution bought and retired the carbon credit.


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
1. As offsets are generated, tokens are added to the FA2 token. Whilst this is an incremental process, in practice we anticipate this will be done in bulk periodically.
1. An organisation will acquire tokens, with the FA2 owner assigning them to the organisations custodian contract. Again, this is expected to be a periodic bulk purchase initially, similar to how offsets are bought today.
1. The organisation will then synchronise their custodian contract with the FA2 contract, so the new credits are now on the ledger in the custodian contract.
1. The credits will then most likely be divided between off-chain entities at the same time.
1. As the organisation goes about its business, carbon emmisions will be gradually generated, and as part of that process, tokens will be retired.

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

The majority of management actions in X4C are batch operations, and the keys used for those operations should be managed by a human using one or more cold wallets that are only brought online briefly to carry out specific actions. Ideally these wallets would be a hardware backed wallet like [Ledger](https://www.ledger.com/tezos-wallet) or [Trezor](https://trezor.io).

For the online part of the X4C service, where retirements are carried out on a continuous basis via a web-service, a hot wallet will be required. As should now be obvious, this is then then part of the system at most risk. We can mitigate some of that risk by following these two guidelines:

1. No wallets with any sort of significant power should be stored on a publicly reachable server (so neither FA2 Oracle or Custodian Owner).
1. No private-keys should be left on any publicly reachable server.


Note that by "publicly reachable" I mean any server that your web service connects to, even if that machine isn't on the public facing Internet directly. We have to assume that any node in a cluster that makes up a web-service can be reachable once compromised by an attacker. If your private-keys are on a machine that only response to local network requests from a publicly addressable we have to assume that a determined attacker will compromise the first machine to then reach the second machine.

The solution to this is then twofold:

1. We should use operator wallets for any contract endpoints that require a hot wallet as part of the deployment.
1. We should use an HSM to store the private-key on the server, so as to limit the impact of an attack.

Thus in the X4C system, the hot/cold wallet division would become:

| Key | Type |
|---|---|
| FA2 Owner | Cold |
| Custodian Owner | Cold |
| Custodian Operator | Hot |

We should use as many custodian wallets as makes sense (e.g., if different departments in an organisation have different portals for say retiring offsets for flights via the travel portal versus retiring offsets for ongoing infrastructure related emissions), with each limited to being able to retire only the credits it is allowed to access (this assumes the services are run on different servers, if they reside on the same server then there is no benefit to this).

## Service Infrastructure Implications

Typically a web-service these days consists of many parts (front-end load balancer, service code, database, etc.) running over a number of different machines. In a typical X4C system we will end up with at least the following set of services running:

[pic]

From the perspective of trying to minimise access to the hot wallet, the machine with the HSM should have the smallest possible amount of code running on it with the least flexible service API presented to other machines: this minimises the amount of functinality exposed to someone on the same network (being able to make arbitrary API calls to the machine) and the minimal footprint of code that could be exploited to get onto the machine itself.

From this perspective, we draw the line at the X4C REST service, which offers a minimal "retire" REST API, being what runs on the machine with the HSM. Although services such as [signatory](https://signatory.io) make it possible for X4C's REST service to run on another node and make signing requests, that offers an API much more open to abuse by someone who gets onto that network. By only having miminal Tezos interaction code in the X4C REST service, and all other X4C business logic on another node, we minimise the amount of exploitable code that runs on the HSM machine.

Obviously there are physical security considerations when using an HSM, but those are outwith the scope of this document.


