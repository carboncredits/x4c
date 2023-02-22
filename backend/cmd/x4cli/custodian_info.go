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

type CustodianSnapshot struct {
	// Basic info (will include bigmap IDs)
	x4c.CustodianStorage

	// Bigmaps that are stored. We can't output these as JSON because
	// unlike bigmaps, JSON can only have simple types as dictionary
	// so these are just for holding the data
	LedgerContents         x4c.Ledger            `json:"-"`
	ExternalLedgerContents x4c.ExternalLedger    `json:"-"`
	MetadataContents       x4c.CustodianMetadata `json:"-"`

	// These are the versions of the above for JSON output
	JSONSafeLedger         []map[string]interface{} `json:"ledger_bigmap"`
	JSONSafeExternalLedger []map[string]interface{} `json:"external_ledger_bigmap"`
	JSONSafeMetadata       []map[string]interface{} `json:"metadata_bigmap"`

	// Emits on this contract
	InternalMintEvents     []x4c.InternalMintEvent     `json:"internal_mint_events"`
	InternalTransferEvents []x4c.InternalTransferEvent `json:"internal_transfer_events"`
	RetireEvents           []x4c.CustodianRetireEvent  `json:"retire_events"`
}

type custodianInfoCommand struct{}

func NewCustodianInfoCommand() (cli.Command, error) {
	return custodianInfoCommand{}, nil
}

func (c custodianInfoCommand) Help() string {
	return `usage: x4cli custodian info [-json] CONTRACT

Shows information about the specified custodian contract. Defaults to human
readable, but can also output JSON to snapshot the contract.`
}

func (c custodianInfoCommand) Synopsis() string {
	return "Shows information about a custodian contract."
}

func (c custodianInfoCommand) Run(rawargs []string) int {

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
			fmt.Fprintf(os.Stderr, "Contract address '%s' is not valid: %v\n", args[0], err)
			return 1
		}
	}

	// Gather all the info, and then work out if we're displaying it for humans or as JSON
	ctx := context.Background()
	var storage x4c.CustodianStorage
	err = client.GetContractStorage(contract, ctx, &storage)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to get contract storage: %v.\n", err)
		return 1
	}
	ledger, err := storage.GetLedger(ctx, client)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read ledger: %v\n", err)
		return 1
	}
	external_ledger, err := storage.GetExternalLedger(ctx, client)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read external ledger: %v\n", err)
		return 1
	}
	metadata, err := storage.GetCustodianMetadata(ctx, client)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read metadata: %v\n", err)
		return 1
	}
	mint_events, err := x4c.GetInternalMintEvents(ctx, client, contract)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to get internal mint events: %v\n", err)
		return 1
	}
	transfer_events, err := x4c.GetInternalTransferEvents(ctx, client, contract)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to get internal transfer events: %v\n", err)
		return 1
	}
	retirement_events, err := x4c.GetCustodianRetireEvents(ctx, client, contract)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to get retirement events: %v\n", err)
		return 1
	}

	info := CustodianSnapshot{
		CustodianStorage:       storage,
		LedgerContents:         ledger,
		ExternalLedgerContents: external_ledger,
		MetadataContents:       metadata,
		InternalMintEvents:     mint_events,
		InternalTransferEvents: transfer_events,
		RetireEvents:           retirement_events,
	}

	if outputJson {
		err = displayCustodianAsJson(info)
	} else {
		err = displayCustodianAsText(client, info)
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		return 1
	}
	return 0
}

func displayCustodianAsText(client tzclient.Client, info CustodianSnapshot) error {
	custodianName := client.FindNameForAddress(info.Custodian)
	fmt.Printf("Custodian: %v\n", custodianName)

	fmt.Printf("\nLedger:\n")
	{
		t := tabby.New()
		t.AddHeader("KYC", "Minter", "ID", "Amount")
		for key, value := range info.LedgerContents {
			kyc, err := key.DecodeKYC()
			if err != nil {
				kyc = key.RawKYC
			}
			minter := client.FindNameForAddress(key.Token.Address)
			t.AddLine(kyc, minter, key.Token.TokenID, value)
		}
		t.Print()
	}

	fmt.Printf("\nOperators:\n")
	{
		t := tabby.New()
		t.AddHeader("Operator", "KYC", "Token ID")
		for _, operator := range info.Operators {
			kyc, err := operator.DecodeKYC()
			if err != nil {
				kyc = operator.RawKYC
			}
			operatorName := client.FindNameForAddress(operator.Operator)
			t.AddLine(operatorName, kyc, operator.TokenID)
		}
		t.Print()
	}

	fmt.Printf("\nExternal ledger:\n")
	{
		t := tabby.New()
		t.AddHeader("Minter", "ID", "Amount")

		for key, value := range info.ExternalLedgerContents {
			minter := client.FindNameForAddress(key.Address)
			t.AddLine(minter, key.TokenID, value)
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

	fmt.Printf("\nInternal mints:\n")
	{
		t := tabby.New()
		t.AddHeader("ID", "Time", "Token Address", "Token ID", "Amount", "New total")
		for _, event := range info.InternalMintEvents {
			t.AddLine(event.Identifier, event.Timestamp, event.Token.Address, event.Token.TokenID, event.Amount, event.NewTotal)
		}
		t.Print()
	}

	fmt.Printf("\nInternal transfers:\n")
	{
		t := tabby.New()
		t.AddHeader("ID", "Time", "Token Address", "Token ID", "From", "To", "Amount")
		for _, event := range info.InternalTransferEvents {
			t.AddLine(event.Identifier, event.Timestamp, event.Token.Address, event.Token.TokenID, event.From(), event.To(), event.Amount)
		}
		t.Print()
	}

	fmt.Printf("\nRetirements:\n")
	{
		t := tabby.New()
		t.AddHeader("ID", "Time", "Token Address", "Token ID", "By", "KYC", "Amount", "Reason")
		for _, event := range info.RetireEvents {
			t.AddLine(event.Identifier, event.Timestamp, event.Token.Address, event.Token.TokenID, event.RetiringParty, event.RetiringPartyKyc, event.Amount, event.Reason)
		}
		t.Print()
	}

	return nil
}

func displayCustodianAsJson(info CustodianSnapshot) error {

	// we need to populate the JSON safe fields here
	safe_ledger := make([]map[string]interface{}, 0, len(info.LedgerContents))
	for key, value := range info.LedgerContents {
		item := make(map[string]interface{}, 2)
		item["key"] = key
		item["value"] = value
		safe_ledger = append(safe_ledger, item)
	}
	info.JSONSafeLedger = safe_ledger

	safe_external_ledger := make([]map[string]interface{}, 0, len(info.ExternalLedgerContents))
	for key, value := range info.ExternalLedgerContents {
		item := make(map[string]interface{}, 2)
		item["key"] = key
		item["value"] = value
		safe_external_ledger = append(safe_external_ledger, item)
	}
	info.JSONSafeExternalLedger = safe_external_ledger

	safe_metadata := make([]map[string]interface{}, 0, len(info.MetadataContents))
	for key, value := range info.MetadataContents {
		item := make(map[string]interface{}, 2)
		item["key"] = key
		item["value"] = value
		safe_metadata = append(safe_metadata, item)
	}
	info.JSONSafeMetadata = safe_metadata

	data, err := json.Marshal(info)
	if err != nil {
		return fmt.Errorf("failed to marshal snapshot: %w", err)
	}

	fmt.Println(string(data))

	return nil
}
