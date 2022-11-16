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

type custodianInternalTransfer struct{}

func NewCustodianInternalTransferCommand() (cli.Command, error) {
	return custodianInternalTransfer{}, nil
}

func (c custodianInternalTransfer) Help() string {
	return `usage: x4cli custodian internal_transfer CONTRACT SIGNER FA2_CONTRACT TOKEN_ID AMOUNT CURRENT_KYC NEW_KYC

Updates the internal ledger as to who the tokens belong off-chain.`
}

func (c custodianInternalTransfer) Synopsis() string {
	return "Updates the internal ledger as to who the tokens belong off-chain."
}

func (c custodianInternalTransfer) Run(args []string) int {
	if len(args) != 7 {
		fmt.Fprintf(os.Stderr, "Incorrect number of arguments.\n\n%s", c.Help())
		return 1
	}

	client, err := tzclient.LoadDefaultClient()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to find info: %v.\n", err)
		return 1
	}

	// arg0 - Custodian contract name/address
	contract, err := client.ContractByName(args[0])
	if err != nil {
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

	// arg4 - amount
	amount, err := strconv.ParseInt(args[4], 10, 64)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to parse amount %v: %v", args[4], err)
		return 1
	}

	// arg5 - current kyc
	current_kyc := args[5]

	// arg6 - new kyc
	new_kyc := args[6]

	ctx := context.Background()

	operation_hash, err := x4c.CustodianInternalTransfer(ctx, client, contract, signer, fa2, token_id, amount, current_kyc, new_kyc)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to update operators: %v", err)
		return 1
	}

	fmt.Printf("Submitted operation successfully as %s\n", operation_hash)

	return 0
}
