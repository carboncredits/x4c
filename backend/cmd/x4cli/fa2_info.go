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

type fa2InfoCommand struct{}

func NewFA2InfoCommand() (cli.Command, error) {
	return fa2InfoCommand{}, nil
}

func (c fa2InfoCommand) Help() string {
	return "Shows information about an fa2 contract."
}

func (c fa2InfoCommand) Synopsis() string {
	return "Shows information about an fa2 contract."
}

func (c fa2InfoCommand) Run(args []string) int {
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
	var storage x4c.FA2Storage
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

	fmt.Printf("Token metadata:\n")
	token_metadata, err := storage.GetTokenMetadata(ctx, client)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read token metadata: %v", err)
		return 1
	}
	for key, value := range token_metadata {
		fmt.Printf("%v: %v\n", key, value)
	}

	return 0
}
