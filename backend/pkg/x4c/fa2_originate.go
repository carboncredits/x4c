package x4c

import (
	"context"

	"blockwatch.cc/tzgo/micheline"
	"blockwatch.cc/tzgo/tezos"

	"quantify.earth/x4c/pkg/tzclient"
)

func FA2Originate(
	ctx context.Context,
	client tzclient.TezosClient,
	contractBytes []byte,
	signer tzclient.Wallet,
	oracle tezos.Address,
) (tzclient.Contract, error) {

	storage := micheline.NewPair(
		micheline.NewCode(micheline.D_PAIR,
			micheline.NewPair(
				micheline.NewSeq(),
				micheline.NewSeq(),
			),
			micheline.NewSeq(),
			micheline.NewString(oracle.String()),
		),
		micheline.NewSeq(),
	)

	res, err := client.Originate(ctx, signer, contractBytes, storage)

	return res, err
}