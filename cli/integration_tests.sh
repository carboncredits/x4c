#!/bin/bash
set -e

sleep 5

shopt -s expand_aliases
alias tcli='tezos-client --endpoint ${TEZOS_RPC_HOST}'

# Set up the client with the sandbox node
tcli config reset
tcli bootstrapped

# Import the standard wallets from the sandbox so we can access their tez
tcli import secret key alice unencrypted:edsk3QoqBuvdamxouPhin7swCvkQNgq4jP5KZPbwWNnwdZpSpJiEbq --force
tcli import secret key bob unencrypted:edsk3RFfvaFaxbHx8BMtEW1rKQcPtDML3LXjNqMNLCzC3wLC1bWbAt --force

# Create two wallets to hold our contracts, and another one
# that will be the operator used for the web service frontend
tcli gen keys 4CTokenOracle --force
tcli transfer 1000 from alice to 4CTokenOracle --burn-cap 1
tcli gen keys OffChainCustodian --force
tcli transfer 1000 from alice to OffChainCustodian --burn-cap 1
tcli gen keys CustodianOperator --force
tcli transfer 1000 from alice to CustodianOperator --burn-cap 1

# this is more a sanity check of the world
x4c info

# make a couple of contracts
x4c fa2 originate 4CTokenContract fa2.michelson 4CTokenOracle
x4c custodian originate CustodianContract custodian.michelson OffChainCustodian

# this is more a sanity check of the world with contracts
x4c info

# Mint some tokens for the custodian contract
x4c fa2 add_token 4CTokenOracle 123 "Test project" "http://blah.com/" 4CTokenContract
x4c fa2 mint 4CTokenOracle CustodianContract 123 10000 4CTokenContract

# Display some info about the contract (this will need the indexer)
c=0
until x4c fa2 info | grep -q "123";
do
  ((c++)) && ((c==20)) && exit 1
  sleep 1;
done
x4c fa2 info

# now transfer tokens to custodian
x4c custodian internal_mint OffChainCustodian CustodianContract 4CTokenContract 123

# Display some info about the contract (this will need the indexer)
c=0
until x4c custodian info CustodianContract | grep -q "123";
do
  ((c++)) && ((c==20)) && exit 1
  sleep 1;
done
x4c custodian info CustodianContract

# Assign some tokens to a department and make sure the operator can access them
x4c custodian internal_transfer OffChainCustodian CustodianContract 4CTokenContract 123 500 self compsci
x4c custodian add_operator OffChainCustodian CustodianContract CustodianOperator 123 compsci

c=0
until x4c custodian info CustodianContract | grep -q "compsci";
do
  ((c++)) && ((c==20)) && exit 1
  sleep 1;
done
x4c custodian info CustodianContract

# Have department retire credits
x4c custodian retire CustodianOperator CustodianContract 4CTokenContract compsci 123 20 flights

# Check that the balances on both the custodian contract and the root contract are now adjusted

c=0
until x4c custodian info CustodianContract | grep -q "480";
do
  ((c++)) && ((c==20)) && exit 1
  sleep 1;
done
x4c custodian info CustodianContract

c=0
until x4c fa2 info | grep -q "9980";
do
  ((c++)) && ((c==20)) && exit 1
  sleep 1;
done
x4c fa2 info

# Check that if we revoke the operator they can't still retire redits
x4c custodian remove_operator OffChainCustodian CustodianContract CustodianOperator 123 compsci
x4c custodian retire CustodianOperator CustodianContract 4CTokenContract compsci 123 20 flights || echo "Retire failed as expected"

# It's hard to test that the above didn't work, as we might just have the indexer being slow. So to
# confirm that the above didn't work, retire some more credits and check that we get the expected
# result, as we know that operations should happen in the right order at least.
x4c custodian retire OffChainCustodian CustodianContract 4CTokenContract compsci 123 5 flights

c=0
until x4c fa2 info | grep -q "9975";
do
  ((c++)) && ((c==20)) && exit 1
  sleep 1;
done
x4c fa2 info
