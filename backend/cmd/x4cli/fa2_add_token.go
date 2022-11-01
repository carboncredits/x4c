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

type addTokenCommand struct{}

func NewAddTokenCommand() (cli.Command, error) {
	return addTokenCommand{}, nil
}

func (c addTokenCommand) Help() string {
	return "Add a new token."
}

func (c addTokenCommand) Synopsis() string {
	return "Add a new token."
}

func (c addTokenCommand) Run(args []string) int {
	if len(args) != 5 {
		fmt.Fprintf(os.Stderr, "Expected: contract oracle token_id token_owner amount\n")
		return 1
	}

	client, err := tzclient.LoadDefaultClient()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to find info: %v.\n", err)
		return 1
	}

	// arg0 - FA2 contract name/address
	contract, ok := client.Contracts[args[0]]
	if !ok {
		contract, err = tzclient.NewContractWithAddress("contract", args[0])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Contract address is not valid: %v\n", err)
			return 1
		}
	}

	// arg1 - Oracle name/address
	oracle, ok := client.Wallets[args[1]]
	if !ok {
		oracle, err = tzclient.NewWalletWithAddress("oracle", args[1])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Oracle address is not valid: %v\n", err)
			return 1
		}
	}

	// arg2 - token ID
	token_id, err := strconv.ParseInt(args[2], 10, 64)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to parse token ID %v: %v\n", args[2], err)
		return 1
	}

	// arg3 - token title
	title := args[3]

	// arg4 - token url
	url := args[4]

	ctx := context.Background()

	operation_hash, err := x4c.FA2AddToken(ctx, client, contract, oracle, token_id, title, url)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to add token: %v\n", err)
		return 1
	}

	fmt.Printf("Submitted operation successfully as %s\n", operation_hash)

	return 0
}
