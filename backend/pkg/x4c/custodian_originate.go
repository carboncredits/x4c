package x4c

import (
	"context"

	"blockwatch.cc/tzgo/micheline"
	"blockwatch.cc/tzgo/tezos"

	"quantify.earth/x4c/pkg/tzclient"
)

func CustodianOriginate(
	ctx context.Context,
	client tzclient.TezosClient,
	contractBytes []byte,
	signer tzclient.Wallet,
	owner tezos.Address,
) (tzclient.Contract, error) {

	// (Pair (Pair (Pair "tz1YYBnLs471SKKReLn8nV47Tqh9VDgPoE7F" {}) {} {}) {})

	storage := micheline.NewPair(
		micheline.NewCode(micheline.D_PAIR,
			micheline.NewPair(
				micheline.NewString(owner.String()),
				micheline.NewSeq(),
			),
			micheline.NewSeq(),
			micheline.NewSeq(),
		),
		micheline.NewSeq(),
	)

	res, err := client.Originate(ctx, signer, contractBytes, storage)

	return res, err
}
