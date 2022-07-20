Summary
=======

This directory contains a command line tool that just wraps the contract access so that you can avoid having to write michelson types at the command line. Currently it uses the tezos-client storage to find keys and contracts.

Also, `src/x4c` acts as a typescript library that in future we can use on the 4C website for interacting with the contracts.


Building
========

To build the tools you will need node and typescript installed. Once you have node, ensure that typescript is globally installed:

``` $ npm install -g typescript ```

Then in this directory fetch the dependancies:

``` $ npm install ```

After that completes, compile the typescript:

``` $ tsc ```

Then you can either run it locally by calling:

``` $ node . ```

Or you can install it as a tool locally:

```
$ npm link
$ x4c
```

The rest of the document assumes the later form.



Usage
=====

This tool assumes that tezos-client has been used to set up the keys and contracts. You can see what, if any, keys and contracts you have available by running:

```
$ x4c info
 Alias                  Hash                                   Contract type   Default 
 UoCCustodian           tz1bptwyLaQXmM7yFQaTYrRYGiyxb4h9GCsp   Wallet                  
 4CTokenOracle          tz1hcU2KvWpiFWRJH2WbK6QZZVkrpUGNLMXq   Wallet                  
 faucet                 tz1VFSrJiZfrFvya9magpd92MPDaqjEMg3hs   Wallet                  
 UoCCustodianContract   KT1TFHTEhcu55YedRiSTHa84BJZm6hCvi8cd   Custodian               
 4CTokenHolder          KT1JuohUpviPwoTCtHRo38V6T4goU8QxdE7w   FA2             x        
```

The script does a little checking and takes a guess at which contracts you have instantiated on the chain based on their method lists. In calls that use FA2, if you only have a single FA2 contract in your client info you don't need to specify it when issing fa2 commands.

You can see the supported fa2 subcommands thus:

```
$ x4c fa2

  USAGE

    x4c fa2 <subcommand>

  SUBCOMMANDS
  
  add_token - Define a new token ID                    
  info      - Fetch FA2 contract storage               
  mint      - Mint new tokens                          
  originate - Create new FA2 contract instance on chain
  retire    - Retire tokens from chain                 
  transfer  - Assign tokens to another address         
```

And you can do the same with the `custodian` command. 

```
$ x4c custodian   
USAGE

  x4c custodian <subcommand>

SUBCOMMANDS

  info              - Fetch custodian contract storage                              
  internal_mint     - Synchronise token status for custodian with main FA2 contract.
  internal_transfer - Assign tokens to off chain entities.                          
  originate         - Create new Custodian contract instance on chain               
  retire            - Retire tokens from custorian.  
```


Running the bare subcommand will tell you which arguments you need for a given call:

```
$ x4c fa2 add_token
ERR Expecting parameter(s) `oracle-str`, `token-id`, `title`, `url`.

  Define a new token ID

  USAGE

    x4c fa2 add_token <oracle-str> <token-id> <title> <url> [contract-str]

  PARAMETERS

    oracle-str   - FA2 Oracle Key
    token-id     - Token ID
    title        - Project Title
    url          - Project URL
    contract-str - FA2 Contract key (not needed if only one shows in info)
```

Where you see an argument that requires a key you can use either the hash or the name assiged in tezos-client. For example, both of these work:

```
# Using tezos-client names
$ x4c custodian internal_mint UoCCustodian UoCCustodianContract 4CTokenHolder 147

# Using tezos chain hashes
$ x4c custodian internal_mint tz1bptwyLaQXmM7yFQaTYrRYGiyxb4h9GCsp KT1TFHTEhcu55YedRiSTHa84BJZm6hCvi8cd ...
```

Note that originating new contracts will update your tezos-client's contracts data to keep the two in sync.



