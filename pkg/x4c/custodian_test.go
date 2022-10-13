package x4c

import (
	"context"
	"encoding/json"
	"fmt"
	"testing"

	"blockwatch.cc/tzgo/micheline"

	"quantify.earth/x4c/pkg/tzclient"
	"quantify.earth/x4c/pkg/tzkt"
)

type mockClient struct {
	ShouldError bool
	Items       map[int64][]tzkt.BigMapItem
}

func newmockClient() mockClient {
	return mockClient{
		Items: make(map[int64][]tzkt.BigMapItem),
	}
}

func (c *mockClient) addBigMap(identifier int64, items []tzkt.BigMapItem) {
	c.Items[identifier] = items
}

func (c mockClient) GetContractStorage(target tzclient.Contract, ctx context.Context, storage interface{}) error {
	if c.ShouldError {
		return fmt.Errorf("Test should fail")
	}
	return nil
}

func (c mockClient) GetBigMapContents(ctx context.Context, identifier int64) ([]tzkt.BigMapItem, error) {
	if c.ShouldError {
		return nil, fmt.Errorf("Test should fail")
	}
	if items, ok := c.Items[identifier]; ok {
		return items, nil
	} else {
		// The tzkt API returns empty list if you ask for an invalid ID
		// Though you could also argue we should return other garbage here, as that's also
		// a valid response, that's handled in other test cases
		return make([]tzkt.BigMapItem, 0), nil
	}
}

func (c mockClient) GetOperationInformation(ctx context.Context, hash string) ([]tzkt.Operation, error) {
	if c.ShouldError {
		return nil, fmt.Errorf("Test should fail")
	}
	return nil, nil
}

func (c mockClient) CallContract(ctx context.Context, signedBy tzclient.Wallet, target tzclient.Contract, parameters micheline.Parameters) (string, error) {
	if c.ShouldError {
		return "", fmt.Errorf("Test should fail")
	}
	return "", nil
}

func TestLedgerLoadFail(t *testing.T) {
	client := mockClient{
		ShouldError: true,
	}
	storage := CustodianStorage{}

	ctx := context.Background()
	ledger, err := storage.GetLedger(ctx, client)
	if err == nil {
		t.Errorf("Expected error on GetLedger")
	}
	if ledger != nil {
		t.Errorf("Got unexpected ledger %v", ledger)
	}
}

func TestExternalLedgerLoadFail(t *testing.T) {
	client := mockClient{
		ShouldError: true,
	}
	storage := CustodianStorage{}

	ctx := context.Background()
	ledger, err := storage.GetExternalLedger(ctx, client)
	if err == nil {
		t.Errorf("Expected error on GetLedger")
	}
	if ledger != nil {
		t.Errorf("Got unexpected ledger %v", ledger)
	}
}

func TestBasicLedgerLoad(t *testing.T) {

	bigMapID := int64(314)

	testcases := []struct {
		IsActive    bool
		BigMapID    int64
		KeyJSON     string
		ValueJSON   string
		ExpectError bool
		ExpectItem  bool
	}{
		{
			IsActive:    false,
			BigMapID:    bigMapID,
			KeyJSON:     `{"token": {"token_id": 42, "token_address": "tz1deC7DBmyTU7DtfV7f4YmpbW3xQkBYEwVB"}, "kyc": "0501000000096f74686572206f7267"}`,
			ValueJSON:   "1234",
			ExpectError: false,
			ExpectItem:  false,
		},
		{
			IsActive:    true,
			BigMapID:    bigMapID,
			KeyJSON:     `{"token": {"token_id": 42, "token_address": "tz1deC7DBmyTU7DtfV7f4YmpbW3xQkBYEwVB"}, "kyc": "0501000000096f74686572206f7267"}`,
			ValueJSON:   "1234",
			ExpectError: false,
			ExpectItem:  true,
		},
		{
			IsActive:    true,
			BigMapID:    bigMapID,
			KeyJSON:     `{"token": {"token_id": 42, "token_address": "tz1deC7DBmyTU7DtfV7f4YmpbW3xQkBYEwVB"}, "kyc": "0501000000096f74686572206f7267"}`,
			ValueJSON:   "invalid",
			ExpectError: true,
			ExpectItem:  false,
		},
		{
			IsActive:    true,
			BigMapID:    bigMapID,
			KeyJSON:     `{"token": "invalid", "kyc": "0501000000096f74686572206f7267"}`,
			ValueJSON:   "invalid",
			ExpectError: true,
			ExpectItem:  false,
		},
		{
			IsActive:    true,
			BigMapID:    bigMapID,
			KeyJSON:     `{"token": "invalid", "kyc": "0501000000096f74686572206f7267"}`,
			ValueJSON:   "invalid",
			ExpectError: true,
			ExpectItem:  false,
		},
		{
			IsActive:    true,
			BigMapID:    bigMapID + 1,
			KeyJSON:     `{"token": {"token_id": 42, "token_address": "tz1deC7DBmyTU7DtfV7f4YmpbW3xQkBYEwVB"}, "kyc": "0501000000096f74686572206f7267"}`,
			ExpectError: false,
			ExpectItem:  false,
		},
	}

	for index, testcase := range testcases {

		item := tzkt.BigMapItem{
			Active: testcase.IsActive,
			Key:    json.RawMessage(testcase.KeyJSON),
			Value:  json.RawMessage(testcase.ValueJSON),
		}

		items := make([]tzkt.BigMapItem, 1)
		items[0] = item
		client := newmockClient()
		client.addBigMap(bigMapID, items)

		storage := CustodianStorage{
			Ledger: testcase.BigMapID,
		}
		ctx := context.Background()
		ledger, err := storage.GetLedger(ctx, client)
		if testcase.ExpectError {
			if err == nil {
				t.Errorf("Expected error on test cast %d", index)
			}
			if ledger != nil {
				t.Errorf("Got unexpected ledger on test case %d: %v", index, ledger)
			}
		} else {
			if testcase.ExpectItem {
				if len(ledger) != 1 {
					t.Errorf("Expected ledger to contain one item for case %d, but got %v", index, ledger)
				}
			} else {
				if len(ledger) != 0 {
					t.Errorf("Expected empty ledger for case %d, but got %v", index, ledger)
				}
			}
			if err != nil {
				t.Errorf("Got unexpected error on test case %d: %v", index, err)
			}
		}
	}
}
