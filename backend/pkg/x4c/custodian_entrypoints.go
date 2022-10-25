package x4c

import (
	"context"
	"fmt"
	"math/big"

	"blockwatch.cc/tzgo/micheline"
	"blockwatch.cc/tzgo/tezos"

	"quantify.earth/x4c/pkg/tzclient"
)

func CustodianInternalMint(
	ctx context.Context,
	client tzclient.TezosClient,
	target tzclient.Contract,
	signer tzclient.Wallet,
	token_address tzclient.Contract,
	token_id int64,
) (string, error) {
	bigToken := big.NewInt(token_id)

	// Michelson type:
	// (list %internal_mint (pair (address %token_address) (nat %token_id)))
	parameters := micheline.Parameters{
		Entrypoint: "internal_mint",
		Value: micheline.NewSeq(
			micheline.NewPair(
				micheline.NewString(token_address.Address.String()),
				micheline.NewNat(bigToken),
			),
		),
	}

	return client.CallContract(ctx, signer, target, parameters)
}

func CustodianInternalTransfer(
	ctx context.Context,
	client tzclient.TezosClient,
	target tzclient.Contract,
	signer tzclient.Wallet,
	token_address tzclient.Contract,
	token_id int64,
	amount int64,
	current_kyc string,
	new_kyc string,
) (string, error) {
	bigToken := big.NewInt(token_id)
	bigAmount := big.NewInt(amount)

	// Michelson type:
	// (list %internal_transfer (pair (bytes %from_)
	//   (pair (address %token_address)
	//         (list %txs (pair (bytes %to_)
	//                         (pair (nat %token_id) (nat %amount)))))))
	parameters := micheline.Parameters{
		Entrypoint: "internal_transfer",
		Value: micheline.NewSeq(
			micheline.NewPair(
				micheline.NewString(current_kyc),
				micheline.NewPair(
					micheline.NewString(token_address.Address.String()),
					micheline.NewSeq(
						micheline.NewPair(
							micheline.NewString(new_kyc),
							micheline.NewPair(
								micheline.NewNat(bigToken),
								micheline.NewNat(bigAmount),
							),
						),
					),
				),
			),
		),
	}
	return client.CallContract(ctx, signer, target, parameters)
}

const (
	AddOperator = iota + 1
	RemoveOperator
)

type CustodianOperatorUpdateInfo struct {
	Owner      string
	Operator   tezos.Address
	TokenID    int64
	UpdateType int
}

func CustodianUpdateOperators(
	ctx context.Context,
	client tzclient.TezosClient,
	target tzclient.Contract,
	signer tzclient.Wallet,
	update_list []CustodianOperatorUpdateInfo,
) (string, error) {
	operator_list := make([]micheline.Prim, 0, len(update_list))
	for index, operator := range update_list {
		var update_type micheline.OpCode
		switch operator.UpdateType {
		case AddOperator:
			update_type = micheline.D_LEFT
		case RemoveOperator:
			update_type = micheline.D_RIGHT
		default:
			return "", fmt.Errorf("update %d had unexpected update type %d", index, operator.UpdateType)
		}
		bigToken := big.NewInt(operator.TokenID)
		update := micheline.NewCode(
			update_type,
			micheline.NewPair(
				micheline.NewBytes([]byte(operator.Owner)),
				micheline.NewPair(
					micheline.NewString(operator.Operator.String()),
					micheline.NewNat(bigToken),
				),
			),
		)
		operator_list = append(operator_list, update)
	}
	fmt.Printf("ops: %v\n", operator_list)

	// Michelson type:
	// (list %update_internal_operators (or
	//                                   (pair %add_operator (bytes %token_owner)
	//                                                       (pair (address %token_operator)
	//                                                             (nat %token_id)))
	//                                   (pair %remove_operator (bytes %token_owner)
	//                                                          (pair (address %token_operator)
	//                                                                (nat %token_id)))))
	parameters := micheline.Parameters{
		Entrypoint: "update_internal_operators",
		Value: micheline.Prim{
			Type: micheline.PrimSequence,
			Args: operator_list,
		},
	}

	return client.CallContract(ctx, signer, target, parameters)
}

func CustodianRetire(
	ctx context.Context,
	client tzclient.TezosClient,
	target tzclient.Contract,
	signer tzclient.Wallet,
	token_address tzclient.Contract,
	token_id int64,
	kyc string,
	amount int64,
	reason string,
) (string, error) {
	bigAmount := big.NewInt(amount)
	bigToken := big.NewInt(token_id)

	// Michelson type:
	// (list %retire (pair (address %token_address)
	//                	(list %txs (pair (pair (nat %amount) (bytes %retiring_data))
	//                                	(pair (bytes %retiring_party_kyc) (nat %token_id))))))
	parameters := micheline.Parameters{
		Entrypoint: "retire",
		Value: micheline.NewSeq(
			micheline.NewPair(
				micheline.NewString(token_address.Address.String()),
				micheline.NewSeq(
					micheline.NewPair(
						micheline.NewPair(
							micheline.NewNat(bigAmount),
							micheline.NewBytes([]byte(reason)),
						),
						micheline.NewPair(
							micheline.NewBytes([]byte(kyc)),
							micheline.NewNat(bigToken),
						),
					),
				),
			),
		),
	}

	return client.CallContract(ctx, signer, target, parameters)
}
