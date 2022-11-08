package main

import (
	"context"
	"fmt"
	"os"

	"github.com/cheynewallace/tabby"
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

	client, err := tzclient.LoadDefaultClient()
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

	oracleName := client.FindNameForAddress(storage.Oracle)
	fmt.Printf("Oracle: %v\n", oracleName)

	fmt.Printf("\nLedger:\n")
	ledger, err := storage.GetLedger(ctx, client)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read ledger: %v", err)
		return 1
	} else {
		t := tabby.New()
		t.AddHeader("ID", "Owner", "Amount")
		for key, value := range ledger {
			owner := client.FindNameForAddress(key.TokenOwnder)
			t.AddLine(key.TokenIdentifier, owner, value)
		}
		t.Print()
	}

	fmt.Printf("\nToken metadata:\n")
	token_metadata, err := storage.GetTokenMetadata(ctx, client)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read token metadata: %v", err)
		return 1
	} else {
		t := tabby.New()
		t.AddHeader("Token ID", "Key", "Value")
		for tokenID, tokenInfo := range token_metadata {
			for key, value := range tokenInfo.TokenInformation {
				t.AddLine(tokenID, key, value)
			}
		}
		t.Print()
	}

	fmt.Printf("Retirements:\n")
	{
		events, err := x4c.GetFA2RetireEvents(ctx, client, contract)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Failed to get retirement events: %v\n", err)
			return 1
		}
		t := tabby.New()
		t.AddHeader("ID", "Time", "Reason")
		for _, event := range events {
			t.AddLine(event.Identifier, event.Timestamp, event.Reason)
		}
		t.Print()
	}

	return 0
}
