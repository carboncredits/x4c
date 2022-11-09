package main

import (
	"fmt"
	"os"

	"github.com/mitchellh/cli"

	"quantify.earth/x4c/pkg/tzclient"
)

type infoCommand struct{}

func NewInfoCommand() (cli.Command, error) {
	return infoCommand{}, nil
}

func (c infoCommand) Help() string {
	return "Shows information about known wallets and contracts, as read from $HOME/.tezos-client/"
}

func (c infoCommand) Synopsis() string {
	return "Shows information about known wallets and contracts."
}

func (c infoCommand) Run(args []string) int {
	// at some point we could take the location as an optional arg...
	client, err := tzclient.LoadDefaultClient()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to find info: %v.\n", err)
		return 1
	}

	if len(args) == 1 {
		target := args[0]
		for _, wallet := range client.Wallets {
			if wallet.Name == target {
				fmt.Printf("%s\n", wallet.Address.String())
				return 0
			} else if wallet.Address.String() == target {
				fmt.Printf("%s\n", wallet.Name)
				return 0
			}
		}
		for _, contract := range client.Contracts {
			if contract.Name == target {
				fmt.Printf("%s\n", contract.Address.String())
				return 0
			} else if contract.Address.String() == target {
				fmt.Printf("%s\n", contract.Name)
				return 0
			}
		}
		return 1
	} else {
		for _, wallet := range client.Wallets {
			fmt.Printf("%s: %s\n", wallet.Name, wallet.Address)
		}
		for _, contract := range client.Contracts {
			fmt.Printf("%s: %s\n", contract.Name, contract.Address)
		}
		return 0
	}
}
