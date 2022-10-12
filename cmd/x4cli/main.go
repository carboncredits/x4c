package main

import (
	"os"

	"github.com/maruel/subcommands"
)

var application = &subcommands.DefaultApplication{
	Name:  "x4cli",
	Title: "x4c command line tool.",
	Commands: []*subcommands.Command{
		cmdInfo,
		cmdFA2,
		cmdFA2Mint,
		cmdContract,
	},
}

func main() {
	os.Exit(subcommands.Run(application, nil))
}
