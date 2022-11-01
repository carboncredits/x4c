package main

import (
	"context"
	"fmt"
	"os"
	"strconv"

	"blockwatch.cc/tzgo/tezos"
	"github.com/mitchellh/cli"

	"quantify.earth/x4c/pkg/tzclient"
	"quantify.earth/x4c/pkg/x4c"
)

type mintCommand struct{}

func NewFA2MintCommand() (cli.Command, error) {
	return mintCommand{}, nil
}

func (c mintCommand) Help() string {
	return "Mint more of an existing token. Must have already been added to the contract."
}

func (c mintCommand) Synopsis() string {
	return "Mint more of an existing token."
}

func (c mintCommand) Run(args []string) int {
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
			fmt.Fprintf(os.Stderr, "Oracle address is not valid: %v", err)
			return 1
		}
	}

	// arg2 - token ID
	token_id, err := strconv.ParseInt(args[2], 10, 64)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to parse token ID %v: %v\n", args[2], err)
		return 1
	}

	// arg3 - token owner (could be wallet, contract, or raw address)
	owner := tezos.Address{}
	if wallet, ok := client.Wallets[args[3]]; ok {
		owner = wallet.Address
	} else if contract, ok := client.Contracts[args[3]]; ok {
		owner = contract.Address
	} else {
		owner, err = tezos.ParseAddress(args[3])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Failed to parse token owner %v: %v\n", args[3], err)
			return 1
		}
	}

	// arg4 - amount to mint
	amount, err := strconv.ParseInt(args[4], 10, 64)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to parse amount %v: %v\n", args[4], err)
		return 1
	}

	ctx := context.Background()

	operation_hash, err := x4c.FA2Mint(ctx, client, contract, oracle, token_id, owner, amount)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to mint tokens: %v\n", err)
		return 1
	}

	fmt.Printf("Submitted operation successfully as %s\n", operation_hash)

	return 0
}
