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
	client, err := tzclient.LoadClient("/Users/michael/.tezos-client")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to find info: %v.\n", err)
		return 1
	}

	for _, wallet := range client.Wallets {
		fmt.Printf("%s: %s\n", wallet.Name, wallet.Address)
	}
	for _, contract := range client.Contracts {
		fmt.Printf("%s: %s\n", contract.Name, contract.Address)
	}

	return 0
}
