package main

import (
	"fmt"
	"os"

	"github.com/maruel/subcommands"

	"quantify.earth/x4c/pkg/tzclient"
)

var cmdInfo = &subcommands.Command{
	UsageLine: "info",
	ShortDesc: "Shows known addresses",
	LongDesc:  "Shows known addresses.",
	CommandRun: func() subcommands.CommandRun {
		return &infoRun{}
	},
}

type infoRun struct {
	subcommands.CommandRunBase
}

func (c *infoRun) Run(a subcommands.Application, args []string, env subcommands.Env) int {
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
