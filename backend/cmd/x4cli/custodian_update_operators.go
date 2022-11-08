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

type custodianUpdateOperator struct {
	OperationType int
}

func NewCustodianAddOperatorCommand() (cli.Command, error) {
	return custodianUpdateOperator{
		OperationType: x4c.AddOperator,
	}, nil
}

func NewCustodianRemoveOperatorCommand() (cli.Command, error) {
	return custodianUpdateOperator{
		OperationType: x4c.RemoveOperator,
	}, nil
}

func (c custodianUpdateOperator) Help() string {
	return `usage: x4cli custodian add_operator CONTRACT SIGNER OPERATOR TOKEN_ID TOKEN_OWNER

Add an operator to the custodian contract. This allows the owner to delegate resposibility for retiring tokens.`
}

func (c custodianUpdateOperator) Synopsis() string {
	return "Add an operator to the custodian contract."
}

func (c custodianUpdateOperator) Run(args []string) int {
	if len(args) != 5 {
		fmt.Fprintf(os.Stderr, "Incorrect number of arguments.\n\n%s", c.Help())
		return 1
	}

	client, err := tzclient.LoadDefaultClient()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to find info: %v.\n", err)
		return 1
	}

	// arg0 - Custodian contract name/address
	contract, ok := client.Contracts[args[0]]
	if !ok {
		contract, err = tzclient.NewContractWithAddress("contract", args[0])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Contract address is not valid: %v\n", err)
			return 1
		}
	}

	// arg1 - Signer name/address
	signer, ok := client.Wallets[args[1]]
	if !ok {
		signer, err = tzclient.NewWalletWithAddress("signer", args[1])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Signer address is not valid: %v\n", err)
			return 1
		}
	}

	// arg2 - operator address
	operator, ok := client.Wallets[args[2]]
	if !ok {
		operator, err = tzclient.NewWalletWithAddress("operator", args[2])
		if err != nil {
			fmt.Fprintf(os.Stderr, "Operator address is not valid: %v\n", args[2])
		}
	}

	// arg3 - token ID
	token_id, err := strconv.ParseInt(args[3], 10, 64)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to parse token ID %v: %v\n", args[2], err)
		return 1
	}

	// arg4 - token owner
	owner := args[4]
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to parse token owner %v: %v\n", args[3], err)
		return 1
	}

	ctx := context.Background()

	operator_list := make([]x4c.CustodianOperatorUpdateInfo, 1)
	operator_list[0] = x4c.CustodianOperatorUpdateInfo{
		Owner:      owner,
		Operator:   operator.Address,
		TokenID:    token_id,
		UpdateType: c.OperationType,
	}

	operation_hash, err := x4c.CustodianUpdateOperators(ctx, client, contract, signer, operator_list)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to update operators: %v\n", err)
		return 1
	}

	fmt.Printf("Submitted operation successfully as %s\n", operation_hash)

	return 0
}
