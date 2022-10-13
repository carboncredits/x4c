package main

import (
	"context"
	"fmt"
	"os"
	"strconv"

	"blockwatch.cc/tzgo/tezos"
	"github.com/maruel/subcommands"

	"quantify.earth/x4c/pkg/tzclient"
	"quantify.earth/x4c/pkg/x4c"
)

var cmdFA2Mint = &subcommands.Command{
	UsageLine: "fa2mint",
	ShortDesc: "Mint more of a token",
	LongDesc:  "Mint more of a token. Must have already been added",
	CommandRun: func() subcommands.CommandRun {
		return &fa2mintRun{}
	},
}

type fa2mintRun struct {
	subcommands.CommandRunBase
}

func (c *fa2mintRun) Run(a subcommands.Application, args []string, env subcommands.Env) int {
	if len(args) != 5 {
		fmt.Fprintf(os.Stderr, "Expected: contract oracle token_id token_owner amount\n")
		return 1
	}

	client, err := tzclient.LoadClient("/Users/michael/.tezos-client")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to find info: %v.\n", err)
		return 1
	}

	// arg0 - FA2 contract name/address
	contract, ok := client.Contracts[args[0]]
	if !ok {
		contract, err = tzclient.NewContractWithAddress("contract", args[0])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Contract address is not valid: %v", err)
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
		fmt.Fprintf(os.Stderr, "Failed to parse token ID %v: %v", args[2], err)
		return 1
	}

	// arg3 - token owner
	owner, err := tezos.ParseAddress(args[3])
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to parse token owner %v: %v", args[3], err)
		return 1
	}

	// arg4 - amount to mint
	amount, err := strconv.ParseInt(args[4], 10, 64)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to parse amount %v: %v", args[4], err)
		return 1
	}

	ctx := context.Background()

	operation_hash, err := x4c.FA2Mint(ctx, client, contract, oracle, token_id, owner, amount)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to mint tokens: %v", err)
		return 1
	}

	fmt.Printf("Submitted operation successfully as %s\n", operation_hash)

	return 0
}
