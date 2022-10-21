package main

import (
	"context"
	"fmt"
	"io/ioutil"
	"os"

	"github.com/mitchellh/cli"

	"quantify.earth/x4c/pkg/tzclient"
	"quantify.earth/x4c/pkg/x4c"
)

type custodianOriginateCommand struct{}

func NewCustodianOriginateCommand() (cli.Command, error) {
	return custodianOriginateCommand{}, nil
}

func (c custodianOriginateCommand) Help() string {
	return `usage: x4cli custodian originate ALIAS TZ_FILE_PATH SIGNER OWNER

Originates the custodian contract with the specified address as the owner.`
}

func (c custodianOriginateCommand) Synopsis() string {
	return "Originate the custodian contract."
}

func (c custodianOriginateCommand) Run(args []string) int {
	if (len(args) != 4) && (len(args) != 3) {
		fmt.Fprintf(os.Stderr, "Expected arguments: alias tz_file_path signer [owner]\n")
		return 1
	}

	client, err := tzclient.LoadDefaultClient()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to find info: %v.\n", err)
		return 1
	}

	// arg0 - custodian contract name
	alias := args[0]
	if _, ok := client.Contracts[alias]; ok {
		fmt.Fprintf(os.Stderr, "Contract with name %s already exists", alias)
		return 1
	}

	// arg1 - path to contract
	contractBytes, err := ioutil.ReadFile(args[1])
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to load contract: %v", err)
		return 1
	}

	// arg2 - signer name/address
	signer, ok := client.Wallets[args[2]]
	if !ok {
		fmt.Fprintf(os.Stderr, "Signer name is not found")
		return 1
	}

	// arg2 - owner name/address
	owner := signer.Address
	if len(args) == 4 {
		owner_wallet, ok := client.Wallets[args[3]]
		if !ok {
			owner_wallet, err = tzclient.NewWalletWithAddress("oracle", args[3])
			if err != nil {
				fmt.Fprintf(os.Stderr, "Oracle address is not valid: %v", err)
				return 1
			}
		}
		owner = owner_wallet.Address
	}

	ctx := context.Background()

	contract, err := x4c.CustodianOriginate(ctx, client, contractBytes, signer, owner)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to originate contract: %v", err)
		return 1
	}

	// we should save this to the contracts list
	contract.Name = alias
	err = client.SaveContract(contract)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to save contract %s: %v", contract.Address.String(), err)
		return 1
	}

	fmt.Printf("Submitted originate contract as %s\n", contract.Address.String())

	return 0
}
