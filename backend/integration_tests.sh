#!/bin/bash
set -x
set -e

sleep 5

shopt -s expand_aliases
alias tcli='tezos-client --endpoint ${X4C_TEZOS_RPC_HOST}'

# Set up the client with the sandbox node
tcli config reset
tcli config update
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

# To simulate deployment, the operator key would be in an HSM,
# and so is handled by signatory. Thus we just need to make a note
# of it here and assign it some tez
tcli add address CustodianOperator tz1XnDJdXQLMV22chvL9Vpvbskcwyysn8t4z --force
# tcli gen keys CustodianOperator --force
tcli transfer 1000 from alice to CustodianOperator --burn-cap 1

# this is more a sanity check of the world
x4cli info

# make a couple of contracts
x4cli fa2 originate 4CTokenContract build/fa2.tz 4CTokenOracle
x4cli custodian originate CustodianContract build/custodian.tz OffChainCustodian

# this is more a sanity check of the world with contracts
x4cli info 4CTokenContract

# Mint some tokens for the custodian contract
x4cli fa2 info -json 4CTokenContract | jq ".ledger_bigmap | length" | grep -q "0"

x4cli fa2 add_token 4CTokenContract 4CTokenOracle 123 "Test project" "http://blah.com/"
x4cli fa2 mint 4CTokenContract 4CTokenOracle 123 CustodianContract 10000

# Display some info about the contract (this will need the indexer)
c=0
until x4cli fa2 info -json 4CTokenContract | jq ".ledger_bigmap | length" | grep -q "1";
do
  ((c++)) && ((c==20)) && exit 1
  sleep 1;
done
x4cli fa2 info 4CTokenContract
x4cli fa2 info -json 4CTokenContract | jq ".ledger_bigmap[0].key.token_id" | grep -q "123"
x4cli fa2 info -json 4CTokenContract | jq ".ledger_bigmap[0].value" | grep -q "10000"

# now transfer tokens to custodian
x4cli custodian info -json CustodianContract | jq ".ledger_bigmap | length" | grep -q "0"
x4cli custodian info -json CustodianContract | jq ".internal_mint_events | length" | grep -q "0"

x4cli custodian internal_mint CustodianContract OffChainCustodian 4CTokenContract 123

# Wait for indexer to update then check contents
c=0
until x4cli custodian info -json CustodianContract | jq ".internal_mint_events | length" | grep -q "1";
do
  ((c++)) && ((c==20)) && exit 1
  sleep 1;
done
x4cli custodian info CustodianContract
x4cli custodian info -json CustodianContract | jq ".ledger_bigmap | length" | grep -q "1"
x4cli custodian info -json CustodianContract | jq ".ledger_bigmap[0].key.token.token_id" | grep -q "123"
x4cli custodian info -json CustodianContract | jq ".ledger_bigmap[0].value" | grep -q "10000"

# Assign some tokens to a department and make sure the operator can access them
x4cli custodian info -json CustodianContract | jq ".internal_transfer_events | length" | grep -q "0"

x4cli custodian internal_transfer CustodianContract OffChainCustodian 4CTokenContract 123 500 self compsci

c=0
until x4cli custodian info -json CustodianContract | jq ".internal_transfer_events | length" | grep -q "1";
do
  ((c++)) && ((c==20)) && exit 1
  sleep 1;
done
x4cli custodian info CustodianContract
x4cli custodian info -json CustodianContract | jq ".ledger_bigmap | length" | grep -q "2"
# TODO: KYC value check, which is currently in michelson packed format
x4cli custodian info -json CustodianContract | jq ".ledger_bigmap[0].key.token.token_id" | grep -q "123"
x4cli custodian info -json CustodianContract | jq ".ledger_bigmap[0].value" | grep -q "9500"
x4cli custodian info -json CustodianContract | jq ".ledger_bigmap[1].key.token.token_id" | grep -q "123"
x4cli custodian info -json CustodianContract | jq ".ledger_bigmap[1].value" | grep -q "500"

x4cli custodian info -json CustodianContract | jq ".operators | length" | grep -q "0"
x4cli custodian add_operator CustodianContract OffChainCustodian CustodianOperator 123 compsci
c=0
until x4cli custodian info -json CustodianContract | jq ".operators | length" | grep -q "1";
do
  ((c++)) && ((c==20)) && exit 1
  sleep 1;
done
x4cli custodian info CustodianContract
x4cli custodian info -json CustodianContract | jq ".operators[0].token_operator" | grep -q "tz1XnDJdXQLMV22chvL9Vpvbskcwyysn8t4z"

# Have department retire credits
x4cli custodian retire CustodianContract CustodianOperator 4CTokenContract compsci 123 20 retire1

# Check that the balances on both the custodian contract and the root contract are now adjusted

c=0
until x4cli custodian info -json CustodianContract | jq ".retire_events | length" | grep -q "1";
do
  ((c++)) && ((c==20)) && exit 1
  sleep 1;
done
x4cli custodian info CustodianContract
x4cli custodian info -json CustodianContract | jq ".retire_events[0].Reason" | grep -q "retire1"

c=0
until x4cli fa2 info -json 4CTokenContract | jq ".retire_events | length" | grep -q "1";
do
  ((c++)) && ((c==20)) && exit 1
  sleep 1;
done
x4cli fa2 info 4CTokenContract
x4cli fa2 info -json 4CTokenContract | jq ".ledger_bigmap[0].value" | grep -q "9980"
x4cli fa2 info -json 4CTokenContract | jq ".retire_events[0].Reason" | grep -q "retire1"


# Whilst we have the custodian set up, let's try to retire something via the X4C server

# just check the server is vaguely configured correctly
curl ${X4C_HOST}/info/indexer-url | grep -q "${X4C_TEZOS_INDEX_WEB}"

# try getting a list of tokens
CONTRACT=`x4cli info CustodianContract`
curl ${X4C_HOST}/credit/sources/${CONTRACT} | grep -q compsci

# issue a retirement
FA2=`x4cli info 4CTokenContract`
curl -X POST -H "Content-Type: application/json" -d "{\"minter\": \"${FA2}\", \"kyc\": \"compsci\", \"tokenID\": 123, \"amount\": 10, \"reason\": \"retire3\"}" ${X4C_HOST}/contract/${CONTRACT}/retire | grep -q "Successfully retired credits"

c=0
until x4cli fa2 info -json 4CTokenContract | jq ".retire_events | length" | grep -q "2";
do
  ((c++)) && ((c==20)) && exit 1
  sleep 1;
done
x4cli fa2 info 4CTokenContract
x4cli fa2 info -json 4CTokenContract | jq ".ledger_bigmap[0].value" | grep -q "9970"
x4cli fa2 info -json 4CTokenContract | jq ".retire_events[1].Reason" | grep -q "retire3"

# Check that if we revoke the operator they can't still retire credits
x4cli custodian remove_operator CustodianContract OffChainCustodian CustodianOperator 123 compsci
x4cli custodian retire CustodianContract CustodianOperator 4CTokenContract compsci 123 20 flights || echo "Retire failed as expected"

# It's hard to test that the above didn't work, as we might just have the indexer being slow. So to
# confirm that the above didn't work, retire some more credits and check that we get the expected
# result, as we know that operations should happen in the right order at least.
x4cli custodian retire CustodianContract OffChainCustodian 4CTokenContract compsci 123 5 retire2

c=0
until x4cli fa2 info -json 4CTokenContract | jq ".retire_events | length" | grep -q "3";
do
  ((c++)) && ((c==20)) && exit 1
  sleep 1;
done
x4cli fa2 info 4CTokenContract
x4cli fa2 info -json 4CTokenContract | jq ".ledger_bigmap[0].value" | grep -q "9965"
x4cli fa2 info -json 4CTokenContract | jq ".retire_events[2].Reason" | grep -q "retire2"
