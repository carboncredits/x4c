package main

import (
	"fmt"
	"os"

	"github.com/echa/log"

	"github.com/mitchellh/cli"
)

func main() {
	log.SetLevel(log.LevelError)

	c := cli.NewCLI("x4cli", "0.0.1")
	c.Args = os.Args[1:]
	c.Commands = map[string]cli.CommandFactory{
		"info": NewInfoCommand,

		"fa2 info":      NewFA2InfoCommand,
		"fa2 originate": NewFA2OriginateCommand,
		"fa2 add_token": NewAddTokenCommand,
		"fa2 mint":      NewFA2MintCommand,

		"custodian info":              NewCustodianInfoCommand,
		"custodian originate":         NewCustodianOriginateCommand,
		"custodian internal_mint":     NewCustodianInternalMintCommand,
		"custodian internal_transfer": NewCustodianInternalTransferCommand,
		"custodian add_operator":      NewCustodianAddOperatorCommand,
		"custodian remove_operator":   NewCustodianRemoveOperatorCommand,
		"custodian retire":            NewCustodianRetireCommand,
	}

	exit_status, err := c.Run()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
	}
	os.Exit(exit_status)
}
