package x4c

import (
	"context"
	"encoding/json"
	"testing"

	"quantify.earth/x4c/pkg/tzclient"
	"quantify.earth/x4c/pkg/tzkt"
)

func TestLedgerLoadFail(t *testing.T) {
	client := tzclient.MockClient{
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
	client := tzclient.MockClient{
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
		client := tzclient.NewMockClient()
		client.AddBigMap(bigMapID, items)

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
