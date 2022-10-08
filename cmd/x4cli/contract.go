package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/maruel/subcommands"

	"quantify.earth/x4c/pkg/tzclient"
)

var cmdContract = &subcommands.Command{
	UsageLine: "contract",
	ShortDesc: "Shows information about a contract",
	LongDesc:  "Shows information about a contract.",
	CommandRun: func() subcommands.CommandRun {
		return &contractRun{}
	},
}

type contractRun struct {
	subcommands.CommandRunBase
}

func (c *contractRun) Run(a subcommands.Application, args []string, env subcommands.Env) int {
	if len(args) != 1 {
		fmt.Fprintf(os.Stderr, "Expected a contract name or address\n")
		return 1
	}

	client, err := tzclient.LoadClient("/Users/michael/.tezos-client")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to find info: %w.\n", err)
		return 1
	}

	address := args[0]
	// if this is a name, look it up, otherwise assume it's just an address
	if contract, ok := client.Contracts[address]; ok {
		address = contract.Address
	}

	ctx := context.Background()
	storage, err := client.GetContractStorage(address, ctx)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to get contract storage: %w.\n", err)
		return 1
	}

	buf, _ := json.MarshalIndent(storage, "", "  ")
	fmt.Println(string(buf))

	return 0
}