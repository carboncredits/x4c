package x4c

import (
	"encoding/json"
	"fmt"
	"math/big"
	"sort"

	"blockwatch.cc/tzgo/micheline"
)

// This trio of entries are needed for two reasons:
// 1: You can't have complex types as dictionary keys in JSON, and the Ledger has
//
//	a struct as a key.
//
// 2: We could (and originally did) use map[string]interface for all these, but that
//
//	makes the code to-reload the JSON a lot more complex than having them typed like this
//
// We use the key/value pattern here as it's then consistent with how indexers return maps
// in their JSON APIs.
type JSONSafeFA2Ledger struct {
	Key   FA2Owner    `json:"key"`
	Value json.Number `json:"value"`
}
type JSONSafeFA2Metadata struct {
	Key   string `json:"key"`
	Value string `json:"value"`
}
type JSONSafeFA2TokenMetadata struct {
	Key   json.Number      `json:"key"`
	Value FA2TokenMetadata `json:"value"`
}

// Used for saving out all state and then originating it
type FA2Snapshot struct {
	// Basic info (will include bigmap IDs)
	FA2Storage

	// Bigmaps that are stored. We can't output these as JSON because
	// unlike bigmaps, JSON can only have simple types as dictionary
	// so these are just for holding the data
	LedgerContents        FA2Ledger           `json:"-"`
	MetadataContents      FA2Metadata         `json:"-"`
	TokenMetadataContents FA2TokenMetadataMap `json:"-"`

	// These are the versions of the above for JSON output
	JSONSafeLedger        []JSONSafeFA2Ledger        `json:"ledger_bigmap"`
	JSONSafeMetadata      []JSONSafeFA2Metadata      `json:"metadata_bigmap"`
	JSONSafeTokenMetadata []JSONSafeFA2TokenMetadata `json:"token_metadata_bigmap"`

	// Emits on this contract
	RetireEvents []FA2RetireEvent `json:"retire_events"`
}

func (snapshot *FA2Snapshot) GetJSONLedgerAsMichelson() (micheline.Prim, error) {
	// first do a pass to get it out of the json format, as we need to sort the keys before
	// we submit it to Tezos, and we can't trust the JSON is sorted
	intermediary := make([]JSONSafeFA2Ledger, len(snapshot.JSONSafeLedger))
	for idx, item := range snapshot.JSONSafeLedger {
		intermediary[idx] = item
	}
	sort.Slice(intermediary, func(i, j int) bool {
		a := intermediary[i].Key
		b := intermediary[j].Key
		if a.TokenIdentifier != b.TokenIdentifier {
			return a.TokenIdentifier > b.TokenIdentifier
		} else {
			return a.TokenOwner > b.TokenOwner
		}
	})

	ledger_prims := make(micheline.PrimList, len(intermediary))
	for idx, item := range intermediary {
		amount, err := item.Value.Int64()
		if err != nil {
			return micheline.Prim{}, fmt.Errorf("failed to covert ledger value %v to int64: %w", item.Value, err)
		}
		bigAmount := big.NewInt(amount)
		tokenID, err := item.Key.TokenIdentifier.Int64()
		if err != nil {
			return micheline.Prim{}, fmt.Errorf("failed to covert ledger token id %v to int64: %w", item.Key.TokenIdentifier, err)
		}
		bigToken := big.NewInt(tokenID)
		entry := micheline.Prim{Type: micheline.PrimBinary, OpCode: micheline.D_ELT, Args: []micheline.Prim{
			micheline.NewPair(
				micheline.NewString(item.Key.TokenOwner),
				micheline.NewNat(bigToken),
			),
			micheline.NewNat(bigAmount),
		}}
		ledger_prims[idx] = entry
	}

	ledger := micheline.NewSeq(ledger_prims...)
	return ledger, nil
}

func (snapshot *FA2Snapshot) GetJSONMetadataAsMichelson() (micheline.Prim, error) {
	// first do a pass to get it out of the json format, as we need to sort the keys before
	// we submit it to Tezos, and we can't trust the JSON is sorted
	intermediary := make(map[string]string, len(snapshot.JSONSafeMetadata))
	for _, item := range snapshot.JSONSafeMetadata {
		intermediary[item.Key] = item.Value
	}
	if _, metadata_schema_spotted := intermediary[""]; !metadata_schema_spotted {
		// Add the standard tzip-16 metadata schema description
		intermediary[""] = "https://tzprofiles.com/tzip016_metadata.json"
	}

	keys := make([]string, 0, len(intermediary))
	for key := range intermediary {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	metadata_prims := make(micheline.PrimList, len(intermediary))
	for idx, key := range keys {
		value := intermediary[key]
		metadata_prims[idx] = micheline.Prim{Type: micheline.PrimBinary, OpCode: micheline.D_ELT, Args: []micheline.Prim{
			micheline.NewString(key),
			micheline.NewBytes([]byte(value)),
		}}
	}

	metadata := micheline.NewSeq(metadata_prims...)
	return metadata, nil
}

func (snapshot *FA2Snapshot) GetJSONTokenMetadataAsMichelson() (micheline.Prim, error) {
	// first do a pass to get it out of the json format, as we need to sort the keys before
	// we submit it to Tezos, and we can't trust the JSON is sorted
	intermediary := make(map[int64]FA2TokenMetadata, len(snapshot.JSONSafeTokenMetadata))
	for idx, item := range snapshot.JSONSafeTokenMetadata {
		key, err := item.Key.Int64()
		if err != nil {
			return micheline.Prim{}, fmt.Errorf("failed to decode key for token metadata item %d: %w", idx, err)
		}
		intermediary[key] = item.Value
	}

	keys := make([]int64, 0, len(intermediary))
	for key := range intermediary {
		keys = append(keys, key)
	}
	sort.Slice(keys, func(i, j int) bool { return keys[i] < keys[j] })

	metadata_prims := make(micheline.PrimList, len(intermediary))
	for idx, key := range keys {
		bigToken := big.NewInt(key)
		value := intermediary[key]

		// Interestingly enough it seems maps within bigmaps do not have to have their keys sorted
		keyValuePrims := make(micheline.PrimList, 0, len(value.TokenInformation))
		for key, value := range value.TokenInformation {
			item := micheline.Prim{Type: micheline.PrimBinary, OpCode: micheline.D_ELT, Args: []micheline.Prim{
				micheline.NewString(key),
				micheline.NewBytes([]byte(value)),
			}}
			keyValuePrims = append(keyValuePrims, item)
		}

		metadata_prims[idx] = micheline.Prim{Type: micheline.PrimBinary, OpCode: micheline.D_ELT, Args: []micheline.Prim{
			micheline.NewNat(bigToken),
			micheline.NewPair(
				micheline.NewNat(bigToken),
				micheline.NewSeq(keyValuePrims...),
			),
		}}
	}

	metadata := micheline.NewSeq(metadata_prims...)
	return metadata, nil
}
