package x4c

import (
	"context"
	"math/big"

	"blockwatch.cc/tzgo/micheline"
	"blockwatch.cc/tzgo/tezos"

	"quantify.earth/x4c/pkg/tzclient"
)

func FA2AddToken(
	ctx context.Context,
	client tzclient.TezosClient,
	target tzclient.Contract,
	oracle tzclient.Wallet,
	token_id int64,
	title string,
	url string,
) (string, error) {
	bigToken := big.NewInt(token_id)

	// Michelson type:
	// (list %add_token_id (pair (nat %token_id) (map %token_info string bytes)))
	parameters := micheline.Parameters{
		Entrypoint: "add_token_id",
		Value: micheline.NewSeq(
			micheline.NewPair(
				micheline.NewNat(bigToken),
				micheline.NewSeq(
					micheline.Prim{Type: micheline.PrimBinary, OpCode: micheline.D_ELT, Args: []micheline.Prim{
						micheline.NewString("title"),
						micheline.NewBytes([]byte(title)),
					}},
					micheline.Prim{Type: micheline.PrimBinary, OpCode: micheline.D_ELT, Args: []micheline.Prim{
						micheline.NewString("url"),
						micheline.NewBytes([]byte(url)),
					}},
				),
			),
		),
	}

	return client.CallContract(ctx, oracle, target, parameters)
}

func FA2Mint(
	ctx context.Context,
	client tzclient.TezosClient,
	target tzclient.Contract,
	oracle tzclient.Wallet,
	token_id int64,
	token_owner tezos.Address,
	amount int64,
) (string, error) {
	bigAmount := big.NewInt(amount)
	bigToken := big.NewInt(token_id)

	// Michelson type:
	// (list %mint (pair (pair (address %owner) (nat %qty)) (nat %token_id)))
	parameters := micheline.Parameters{
		Entrypoint: "mint",
		Value: micheline.NewSeq(
			micheline.NewPair(
				micheline.NewPair(
					micheline.NewString(token_owner.String()),
					micheline.NewNat(bigAmount),
				),
				micheline.NewNat(bigToken),
			),
		),
	}

	return client.CallContract(ctx, oracle, target, parameters)
}
