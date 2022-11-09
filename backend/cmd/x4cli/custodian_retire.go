package main

import (
	"context"
	"fmt"
	"os"
	"strconv"

	"github.com/mitchellh/cli"

	"quantify.earth/x4c/pkg/tzclient"
	"quantify.earth/x4c/pkg/x4c"
)

type custodianRetireCommand struct{}

func NewCustodianRetireCommand() (cli.Command, error) {
	return custodianRetireCommand{}, nil
}

func (c custodianRetireCommand) Help() string {
	return `usage: x4cli custodian retire CONTRACT SIGNER TOKEN_ADDRESS OWNER TOKEN_ID AMOUNT REASON

Retires a set of tokens for a given off chain owner. Will update the source FA2 contract.`
}

func (c custodianRetireCommand) Synopsis() string {
	return "Retires a set of tokens for a given off chain owner."
}

func (c custodianRetireCommand) Run(args []string) int {
	if len(args) != 7 {
		fmt.Fprintf(os.Stderr, "Incorrect number of arguments.\n\n%s", c.Help())
		return 1
	}

	client, err := tzclient.LoadDefaultClient()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to find info: %v.\n", err)
		return 1
	}

	// arg0 - Custodian contract name/address
	contract, ok := client.Contracts[args[0]]
	if !ok {
		contract, err = tzclient.NewContractWithAddress("contract", args[0])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Contract address is not valid: %v\n", err)
			return 1
		}
	}

	// arg1 - Signer name/address
	signer, ok := client.Wallets[args[1]]
	if !ok {
		signer, err = tzclient.NewWalletWithAddress("signer", args[1])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Signer address is not valid: %v\n", err)
			return 1
		}
	}

	// arg2 - FA2 contract address
	fa2, ok := client.Contracts[args[2]]
	if !ok {
		fa2, err = tzclient.NewContractWithAddress("contract", args[2])
		if err != nil {
			fmt.Fprintf(os.Stderr, "FA2 contract address is not valid: %v\n", err)
			return 1
		}
	}

	// arg3 - source name
	kyc := args[3]

	// arg4 - token ID
	token_id, err := strconv.ParseInt(args[4], 10, 64)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to parse token ID %v: %v\n", args[4], err)
		return 1
	}

	// arg5 - amount to retire
	amount, err := strconv.ParseInt(args[5], 10, 64)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to parse token ID %v: %v\n", args[5], err)
		return 1
	}

	// arg6 - reason
	reason := args[6]

	ctx := context.Background()

	operation_hash, err := x4c.CustodianRetire(ctx, client, contract, signer, fa2, token_id, kyc, amount, reason)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to retire tokens: %v\n", err)
		return 1
	}

	fmt.Printf("Submitted operation successfully as %s\n", operation_hash)

	return 0
}
