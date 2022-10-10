package x4c

import (
	"context"
	"encoding/json"
	"fmt"

	"quantify.earth/x4c/pkg/tzclient"
)

type TokenID struct {
	TokenID json.Number `json:"token_id"`
	Address string      `json:"token_address"`
}

type LedgerKey struct {
	Token TokenID `json:"token"`
	KYC   string  `json:"kyc"`
}

type Ledger map[LedgerKey]int64

type ExternalLedger map[TokenID]int64

type CustodianStorage struct {
	Ledger         int64    `json:"ledger"`
	Metadata       int64    `json:"metadata"`
	Custodian      string   `json:"custodian"`
	Operators      []string `json:"operators"`
	ExternalLedger int64    `json:"external_ledger"`
}

func (storage *CustodianStorage) GetLedger(ctx context.Context, client tzclient.TezosClient) (Ledger, error) {
	bigmap, err := client.GetBigMapContents(ctx, storage.Ledger)
	if err != nil {
		return nil, fmt.Errorf("failed to get ledger big map: %w", err)
	}

	result := make(Ledger)
	for _, item := range bigmap {
		if !item.Active {
			continue
		}

		var key LedgerKey
		err := json.Unmarshal(item.Key, &key)
		if err != nil {
			return nil, fmt.Errorf("Failed to decode ledger key %v: %w", item.Key, err)
		}
		var value json.Number
		err = json.Unmarshal(item.Value, &value)
		if err != nil {
			return nil, fmt.Errorf("Failed to decode ledger value %v: %w", item.Value, err)
		}
		result[key], err = value.Int64()
		if err != nil {
			return nil, fmt.Errorf("Failed to convert value to correct ledger value %v: %v", value, err)
		}
	}

	return result, nil
}

func (storage *CustodianStorage) GetExternalLedger(ctx context.Context, client tzclient.TezosClient) (ExternalLedger, error) {
	bigmap, err := client.GetBigMapContents(ctx, storage.ExternalLedger)
	if err != nil {
		return nil, fmt.Errorf("failed to get ledger big map: %w", err)
	}

	result := make(ExternalLedger)
	for _, item := range bigmap {
		var key TokenID
		err := json.Unmarshal(item.Key, &key)
		if err != nil {
			return nil, fmt.Errorf("Failed to decode external ledger key %v: %w", item.Key, err)
		}
		var value json.Number
		err = json.Unmarshal(item.Value, &value)
		if err != nil {
			return nil, fmt.Errorf("Failed to decode external ledger value %v: %w", item.Value, err)
		}
		result[key], err = value.Int64()
		if err != nil {
			return nil, fmt.Errorf("Failed to convert external value to correct ledger value %v: %v", value, err)
		}
	}

	return result, nil
}
