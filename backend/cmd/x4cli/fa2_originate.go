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

type fa2OriginateCommand struct{}

func NewFA2OriginateCommand() (cli.Command, error) {
	return fa2OriginateCommand{}, nil
}

func (c fa2OriginateCommand) Help() string {
	return `usage: x4cli fa2 originate ALIAS TZ_FILE_PATH SIGNER ORACLE

Originates the FA2 contract with the specified address as the oracle.`
}

func (c fa2OriginateCommand) Synopsis() string {
	return "Originate the FA2 contract."
}

func (c fa2OriginateCommand) Run(args []string) int {
	if (len(args) != 4) && (len(args) != 3) {
		fmt.Fprintf(os.Stderr, "Expected arguments: alias tz_file_path signer [oracle]\n")
		return 1
	}

	client, err := tzclient.LoadDefaultClient()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to find info: %v.\n", err)
		return 1
	}

	// arg0 - FA2 contract name
	alias := args[0]
	if _, ok := client.Contracts[alias]; ok {
		fmt.Fprintf(os.Stderr, "Contract with name %s already exists\n", alias)
		return 1
	}

	// arg1 - path to contract
	contractBytes, err := ioutil.ReadFile(args[1])
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to load contract: %v\n", err)
		return 1
	}

	// arg2 - signer name/address
	signer, ok := client.Wallets[args[2]]
	if !ok {
		fmt.Fprintf(os.Stderr, "Signer name is not found\n")
		return 1
	}

	// arg2 - Oracle name/address
	oracle := signer.Address
	if len(args) == 4 {
		oracle_wallet, ok := client.Wallets[args[3]]
		if !ok {
			oracle_wallet, err = tzclient.NewWalletWithAddress("oracle", args[3])
			if err != nil {
				fmt.Fprintf(os.Stderr, "Oracle address is not valid: %v\n", err)
				return 1
			}
		}
		oracle = oracle_wallet.Address
	}

	ctx := context.Background()

	contract, err := x4c.FA2Originate(ctx, client, contractBytes, signer, oracle)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to originate contract: %v\n", err)
		return 1
	}

	// we should save this to the contracts list
	contract.Name = alias
	err = client.SaveContract(contract)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to save contract %s: %v\n", contract.Address.String(), err)
		return 1
	}

	fmt.Printf("Submitted originate contract as %s\n", contract.Address.String())

	return 0
}
