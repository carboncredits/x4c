package main

import (
	"context"
	"fmt"
	"os"
	"strconv"

	"github.com/mitchellh/cli"

	"quantify.earth/x4c/pkg/tzclient"
	"quantify.earth/x4c/pkg/x4c"
)

type custodianInternalMint struct{}

func NewCustodianInternalMintCommand() (cli.Command, error) {
	return custodianInternalMint{}, nil
}

func (c custodianInternalMint) Help() string {
	return `usage: x4cli custodian internal_mint CONTRACT SIGNER FA2_CONTRACT TOKEN_ID

Updates this ledger with tokens from the source FA2 contract.`
}

func (c custodianInternalMint) Synopsis() string {
	return "Updates this ledger with tokens from the source FA2 contract."
}

func (c custodianInternalMint) Run(args []string) int {
	if len(args) != 4 {
		fmt.Fprintf(os.Stderr, "Incorrect number of arguments.\n\n%s", c.Help())
		return 1
	}

	client, err := tzclient.LoadClient("/Users/michael/.tezos-client")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to find info: %v.\n", err)
		return 1
	}

	// arg0 - Custodian contract name/address
	contract, ok := client.Contracts[args[0]]
	if !ok {
		contract, err = tzclient.NewContractWithAddress("contract", args[0])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Contract address is not valid: %v", err)
			return 1
		}
	}

	// arg1 - Signer name/address
	signer, ok := client.Wallets[args[1]]
	if !ok {
		signer, err = tzclient.NewWalletWithAddress("signer", args[1])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Signer address is not valid: %v", err)
			return 1
		}
	}

	// arg2 - FA2 contract address
	fa2, ok := client.Contracts[args[2]]
	if !ok {
		fa2, err = tzclient.NewContractWithAddress("contract", args[0])
		if err != nil {
			fmt.Fprintf(os.Stderr, "FA2 contract address is not valid: %v", err)
			return 1
		}
	}

	// arg3 - token ID
	token_id, err := strconv.ParseInt(args[3], 10, 64)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to parse token ID %v: %v", args[2], err)
		return 1
	}

	ctx := context.Background()

	operation_hash, err := x4c.CustodianInternalMint(ctx, client, contract, signer, fa2, token_id)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to update operators: %v", err)
		return 1
	}

	fmt.Printf("Submitted operation successfully as %s\n", operation_hash)

	return 0
}
