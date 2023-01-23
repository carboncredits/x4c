package main

import (
	"context"
	"encoding/json"
	"flag"
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
	return `usage: x4cli fa2 info [-json] CONTRACT

Shows information about the specified custodian contract. Defaults to human
readable, but can also output JSON to snapshot the contract.`
}

func (c fa2InfoCommand) Synopsis() string {
	return "Shows information about an fa2 contract."
}

func (c fa2InfoCommand) Run(rawargs []string) int {

	var outputJson bool
	flags := flag.NewFlagSet("info", flag.ExitOnError)
	flags.BoolVar(&outputJson, "json", false, "output JSON")
	flags.Parse(rawargs)
	args := flags.Args()

	if len(args) != 1 {
		fmt.Fprintf(os.Stderr, "Expected a contract name or address\n")
		return 1
	}

	client, err := tzclient.LoadDefaultClient()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to find info: %v.\n", err)
		return 1
	}

	contract, err := client.ContractByName(args[0])
	if err != nil {
		contract, err = tzclient.NewContractWithAddress(args[0], args[0])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Contract address is not valid: %v", err)
			return 1
		}
	}

	// Gather all the info, and then work out if we're displaying it for humans or as JSON
	ctx := context.Background()
	var storage x4c.FA2Storage
	err = client.GetContractStorage(contract, ctx, &storage)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to get contract storage: %v.\n", err)
		return 1
	}
	ledger, err := storage.GetLedger(ctx, client)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read ledger: %v", err)
		return 1
	}
	metadata, err := storage.GetFA2Metadata(ctx, client)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read FA2 metadata: %v", err)
		return 1
	}
	token_metadata, err := storage.GetTokenMetadata(ctx, client)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read token metadata: %v", err)
		return 1
	}
	retire_events, err := x4c.GetFA2RetireEvents(ctx, client, contract)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to get retirement events: %v\n", err)
		return 1
	}

	info := x4c.FA2Snapshot{
		FA2Storage:            storage,
		LedgerContents:        ledger,
		MetadataContents:      metadata,
		TokenMetadataContents: token_metadata,
		RetireEvents:          retire_events,
	}

	if outputJson {
		err = displayFA2AsJson(info)
	} else {
		err = displayFA2AsText(client, info)
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		return 1
	}
	return 0
}

func displayFA2AsText(client tzclient.Client, info x4c.FA2Snapshot) error {
	oracleName := client.FindNameForAddress(info.Oracle)
	fmt.Printf("Oracle: %v\n", oracleName)

	fmt.Printf("\nLedger:\n")
	{
		t := tabby.New()
		t.AddHeader("ID", "Owner", "Amount")
		for key, value := range info.LedgerContents {
			owner := client.FindNameForAddress(key.TokenOwner)
			t.AddLine(key.TokenIdentifier, owner, value)
		}
		t.Print()
	}

	fmt.Printf("\nMetadata:\n")
	{
		t := tabby.New()
		t.AddHeader("Key", "Value")

		for key, value := range info.MetadataContents {
			t.AddLine(key, value)
		}
		t.Print()
	}

	fmt.Printf("\nToken metadata:\n")
	{
		t := tabby.New()
		t.AddHeader("Token ID", "Key", "Value")
		for tokenID, tokenInfo := range info.TokenMetadataContents {
			for key, value := range tokenInfo.TokenInformation {
				t.AddLine(tokenID, key, value)
			}
		}
		t.Print()
	}

	fmt.Printf("\nRetirements:\n")
	{
		t := tabby.New()
		t.AddHeader("ID", "Time", "Reason")
		for _, event := range info.RetireEvents {
			t.AddLine(event.Identifier, event.Timestamp, event.Reason)
		}
		t.Print()
	}

	return nil
}

func displayFA2AsJson(info x4c.FA2Snapshot) error {

	// we need to populate the JSON safe fields here
	safe_ledger := make([]x4c.JSONSafeFA2Ledger, 0, len(info.LedgerContents))
	for key, value := range info.LedgerContents {
		item := x4c.JSONSafeFA2Ledger{
			Key:   key,
			Value: json.Number(fmt.Sprintf("%v", value)),
		}
		safe_ledger = append(safe_ledger, item)
	}
	info.JSONSafeLedger = safe_ledger

	safe_metadata := make([]x4c.JSONSafeFA2Metadata, 0, len(info.MetadataContents))
	for key, value := range info.MetadataContents {
		item := x4c.JSONSafeFA2Metadata{
			Key:   key,
			Value: value,
		}
		safe_metadata = append(safe_metadata, item)
	}
	info.JSONSafeMetadata = safe_metadata

	safe_token_metadata := make([]x4c.JSONSafeFA2TokenMetadata, 0, len(info.TokenMetadataContents))
	for key, value := range info.TokenMetadataContents {
		item := x4c.JSONSafeFA2TokenMetadata{
			Key:   json.Number(fmt.Sprintf("%v", key)),
			Value: value,
		}
		safe_token_metadata = append(safe_token_metadata, item)
	}
	info.JSONSafeTokenMetadata = safe_token_metadata

	data, err := json.Marshal(info)
	if err != nil {
		return fmt.Errorf("failed to marshal snapshot: %w", err)
	}

	fmt.Println(string(data))

	return nil
}
