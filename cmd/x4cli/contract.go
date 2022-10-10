package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/maruel/subcommands"

	"quantify.earth/x4c/pkg/tzclient"
	"quantify.earth/x4c/pkg/tzkt"
	"quantify.earth/x4c/pkg/x4c"
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
		fmt.Fprintf(os.Stderr, "Failed to find info: %v.\n", err)
		return 1
	}

	address := args[0]
	// if this is a name, look it up, otherwise assume it's just an address
	if contract, ok := client.Contracts[address]; ok {
		address = contract.Address
	}

	ctx := context.Background()
	var storage x4c.CustodianStorage
	err = client.GetContractStorage(address, ctx, &storage)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to get contract storage: %v.\n", err)
		return 1
	}

	bigmap, err := client.GetBigMapContents(ctx, tzkt.BigMapIdentifier(storage.Ledger))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to get ledger contents: %v.\n", err)
		return 1
	}

	buf, _ := json.MarshalIndent(storage, "", "  ")
	fmt.Println(string(buf))

	fmt.Printf("Ledger:\n")
	for _, item := range bigmap {

		var key x4c.LedgerKey
		err := json.Unmarshal(item.Key, &key)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Failed to decode ledger key %v: %v", item.Key, err)
			return 1
		}
		var value json.Number
		err = json.Unmarshal(item.Value, &value)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Failed to decode ledger value: %v", err)
			return 1
		}

		fmt.Printf("%v: %v\n", key, value)
	}

	return 0
}
