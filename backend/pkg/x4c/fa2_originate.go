package x4c

import (
	"context"
	"fmt"

	"blockwatch.cc/tzgo/micheline"

	"quantify.earth/x4c/pkg/tzclient"
)

func FA2Originate(
	ctx context.Context,
	client tzclient.TezosClient,
	contractBytes []byte,
	signer tzclient.Wallet,
	storage FA2Snapshot,
) (tzclient.Contract, error) {

	metadata, err := storage.GetJSONMetadataAsMichelson()
	if err != nil {
		return tzclient.Contract{}, fmt.Errorf("failed to parse metadata: %w", err)
	}

	tokenMetadata, err := storage.GetJSONTokenMetadataAsMichelson()
	if err != nil {
		return tzclient.Contract{}, fmt.Errorf("failed to parse token metadata: %w", err)
	}

	ledger, err := storage.GetJSONLedgerAsMichelson()
	if err != nil {
		return tzclient.Contract{}, fmt.Errorf("failed to parse ledger: %w", err)
	}

	michelson_storage := micheline.NewPair(
		micheline.NewCode(micheline.D_PAIR,
			micheline.NewPair(
				ledger,
				metadata,
			),
			micheline.NewSeq(),
			micheline.NewString(storage.Oracle),
		),
		tokenMetadata,
	)

	res, err := client.Originate(ctx, signer, contractBytes, michelson_storage)

	return res, err
}
