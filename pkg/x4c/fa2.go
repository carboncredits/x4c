package x4c

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"

	"blockwatch.cc/tzgo/micheline"
	"blockwatch.cc/tzgo/tezos"

	"quantify.earth/x4c/pkg/tzclient"
)

type FA2Operator struct {
	TokenOwnder     string `json:"token_owner"`
	TokenOperator   string `json:"token_operator"`
	TokenIdentifier int64  `json:"token_id"`
}

type FA2Owner struct {
	TokenOwnder     string      `json:"token_owner"`
	TokenIdentifier json.Number `json:"token_id"`
}

type FA2Ledger map[FA2Owner]int64

type FA2TokenMetadata struct {
	TokenIdentifier json.Number `json:"token_id"`
	TokenInformation map[string]string `json:"token_info"`
}

type FA2TokenMetadataMap map[int64]FA2TokenMetadata

type FA2Storage struct {
	Oracle        string        `json:"oracle"`
	Ledger        int64         `json:"ledger"`
	Operators     []FA2Operator `json:"operators"`
	TokenMetadata int64         `json:"token_metadata"`
	Metadata      int64         `json:"metadata"`
}

func (storage *FA2Storage) GetLedger(ctx context.Context, client tzclient.TezosClient) (FA2Ledger, error) {
	bigmap, err := client.GetBigMapContents(ctx, storage.Ledger)
	if err != nil {
		return nil, fmt.Errorf("failed to get ledger big map: %w", err)
	}

	result := make(FA2Ledger)
	for _, item := range bigmap {
		if !item.Active {
			continue
		}

		var key FA2Owner
		err := json.Unmarshal(item.Key, &key)
		if err != nil {
			return nil, fmt.Errorf("failed to decode ledger key %v: %w", item.Key, err)
		}
		var value json.Number
		err = json.Unmarshal(item.Value, &value)
		if err != nil {
			return nil, fmt.Errorf("failed to decode ledger value %v: %w", item.Value, err)
		}
		result[key], err = value.Int64()
		if err != nil {
			return nil, fmt.Errorf("failed to convert value to correct ledger value %v: %v", value, err)
		}
	}

	return result, nil
}

func (storage *FA2Storage) GetTokenMetadata(ctx context.Context, client tzclient.TezosClient) (FA2TokenMetadataMap, error) {
	bigmap, err := client.GetBigMapContents(ctx, storage.TokenMetadata)
	if err != nil {
		return nil, fmt.Errorf("failed to get ledger big map: %w", err)
	}

	result := make(FA2TokenMetadataMap)
	for _, item := range bigmap {
		if !item.Active {
			continue
		}

		var keyraw json.Number
		err := json.Unmarshal(item.Key, &keyraw)
		if err != nil {
			return nil, fmt.Errorf("failed to decode ledger key %v: %w", item.Key, err)
		}
		key, err := keyraw.Int64()
		if err != nil {
			return nil, fmt.Errorf("failed to decode key %v: %v", keyraw, err)
		}

		var value FA2TokenMetadata
		err = json.Unmarshal(item.Value, &value)
		if err != nil {
			return nil, fmt.Errorf("failed to decode ledger value %v: %w", item.Value, err)
		}
		result[key] = value
	}

	return result, nil
}

func FA2Mint(
	ctx context.Context,
	client tzclient.TezosClient,
	target tzclient.Contract,
	oracle tzclient.Wallet,
	token_id int64,
	token_owner tezos.Address,
	amount int64,
) error {
	bigAmount := big.NewInt(amount)
	bigToken := big.NewInt(token_id)
	parameters := micheline.Parameters {
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

	err := client.CallContract(ctx, oracle, target, parameters)
	return err
}