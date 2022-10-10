package main

import (
	// "context"
	// "encoding/json"
	// "fmt"
	// "os"
	// "strconv"

	"github.com/maruel/subcommands"
	// "quantify.earth/x4c/pkg/tzclient"
)

var cmdBigmap = &subcommands.Command{
	UsageLine: "bigmap",
	ShortDesc: "Shows information about a bigmap",
	LongDesc:  "Shows information about a bigmap.",
	CommandRun: func() subcommands.CommandRun {
		return &bigmapRun{}
	},
}

type bigmapRun struct {
	subcommands.CommandRunBase
}

func (c *bigmapRun) Run(a subcommands.Application, args []string, env subcommands.Env) int {
	// 	if len(args) != 1 {
	// 		fmt.Fprintf(os.Stderr, "Expected a bigmap ID\n")
	// 		return 1
	// 	}
	//
	// 	client, err := tzclient.LoadClient("/Users/michael/.tezos-client")
	// 	if err != nil {
	// 		fmt.Fprintf(os.Stderr, "Failed to find info: %w.\n", err)
	// 		return 1
	// 	}
	//
	// 	identifier, err := strconv.ParseInt(args[0], 10, 64)
	//
	// 	ctx := context.Background()
	// 	bigmap, err := client.GetBigMap(identifier, ctx)
	// 	if err != nil {
	// 		fmt.Fprintf(os.Stderr, "Failed to get contract storage: %w.\n", err)
	// 		return 1
	// 	}
	//
	// 	buf, _ := json.MarshalIndent(bigmap, "", "  ")
	// 	fmt.Println(string(buf))

	return 0
}
