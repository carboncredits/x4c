package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/mitchellh/cli"

	"quantify.earth/x4c/pkg/tzclient"
	"quantify.earth/x4c/pkg/x4c"
)

type custodianInfoCommand struct{}

func NewCustodianInfoCommand() (cli.Command, error) {
	return custodianInfoCommand{}, nil
}

func (c custodianInfoCommand) Help() string {
	return "Shows information about a contract."
}

func (c custodianInfoCommand) Synopsis() string {
	return "Shows information about a contract."
}

func (c custodianInfoCommand) Run(args []string) int {
	if len(args) != 1 {
		fmt.Fprintf(os.Stderr, "Expected a contract name or address\n")
		return 1
	}

	client, err := tzclient.LoadClient("/Users/michael/.tezos-client")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to find info: %v.\n", err)
		return 1
	}

	contract, ok := client.Contracts[args[0]]
	if !ok {
		contract, err = tzclient.NewContractWithAddress(args[0], args[0])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Contract address is not valid: %v", err)
			return 1
		}
	}

	ctx := context.Background()
	var storage x4c.CustodianStorage
	err = client.GetContractStorage(contract, ctx, &storage)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to get contract storage: %v.\n", err)
		return 1
	}

	buf, _ := json.MarshalIndent(storage, "", "  ")
	fmt.Println(string(buf))

	fmt.Printf("Ledger:\n")
	ledger, err := storage.GetLedger(ctx, client)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read ledger: %v", err)
		return 1
	}
	for key, value := range ledger {
		fmt.Printf("%v: %v\n", key, value)
	}

	fmt.Printf("External ledger:\n")
	external_ledger, err := storage.GetExternalLedger(ctx, client)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read external ledger: %v", err)
		return 1
	}
	for key, value := range external_ledger {
		fmt.Printf("%v: %v\n", key, value)
	}

	return 0
}
