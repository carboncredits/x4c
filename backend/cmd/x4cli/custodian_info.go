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

	client, err := tzclient.LoadDefaultClient()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to find info: %v.\n", err)
		return 1
	}

	contract, ok := client.Contracts[args[0]]
	if !ok {
		contract, err = tzclient.NewContractWithAddress(args[0], args[0])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Contract address is not valid: %v\n", err)
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

	custodianName := client.FindNameForAddress(storage.Custodian)
	fmt.Printf("Custodian: %v\n", custodianName)

	fmt.Printf("\nLedger:\n")
	ledger, err := storage.GetLedger(ctx, client)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read ledger: %v\n", err)
		return 1
	} else {
		t := tabby.New()
		t.AddHeader("KYC", "Minter", "ID", "Amount")
		for key, value := range ledger {
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
		for _, operator := range storage.Operators {
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
	external_ledger, err := storage.GetExternalLedger(ctx, client)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read external ledger: %v\n", err)
		return 1
	} else {
		t := tabby.New()
		t.AddHeader("Minter", "ID", "Amount")

		for key, value := range external_ledger {
			minter := client.FindNameForAddress(key.Address)
			t.AddLine(minter, key.TokenID, value)
		}
		t.Print()
	}

	fmt.Printf("Internal mints:\n")
	{
		events, err := x4c.GetInternalMintEvents(ctx, client, contract)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Failed to get internal mint events: %v\n", err)
			return 1
		}
		t := tabby.New()
		t.AddHeader("ID", "Time", "Token Address", "Token ID", "Amount", "New total")
		for _, event := range events {
			t.AddLine(event.Identifier, event.Timestamp, event.Token.Address, event.Token.TokenID, event.Amount, event.NewTotal)
		}
		t.Print()
	}

	fmt.Printf("Internal transfers:\n")
	{
		events, err := x4c.GetInternalTransferEvents(ctx, client, contract)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Failed to get internal transfer events: %v\n", err)
			return 1
		}
		t := tabby.New()
		t.AddHeader("ID", "Time", "Token Address", "Token ID", "From", "To", "Amount")
		for _, event := range events {
			t.AddLine(event.Identifier, event.Timestamp, event.Token.Address, event.Token.TokenID, event.From(), event.To())
		}
		t.Print()
	}

	fmt.Printf("Retirements:\n")
	{
		events, err := x4c.GetCustodianRetireEvents(ctx, client, contract)
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
