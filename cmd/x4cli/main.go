package main

import (
	"fmt"
	"os"

	"github.com/mitchellh/cli"
)

func main() {
	c := cli.NewCLI("x4cli", "0.0.1")
	c.Args = os.Args[1:]
	c.Commands = map[string]cli.CommandFactory{
		"info": NewInfoCommand,

		"fa2 info":      NewFA2InfoCommand,
		"fa2 add_token": NewAddTokenCommand,
		"fa2 mint":      NewFA2MintCommand,

		"custodian info":            NewCustodianInfoCommand,
		"custodian add_operator":    NewCustodianAddOperator,
		"custodian remove_operator": NewCustodianRemoveOperator,
		// "custodian retire": custodianRetireCommand,
	}

	exit_status, err := c.Run()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v", err)
	}
	os.Exit(exit_status)
}
