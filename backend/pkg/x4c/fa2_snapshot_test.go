package x4c

import (
	"encoding/json"
	"math/big"
	"testing"
)

func TestMetadataMarshalling(t *testing.T) {
	testcases := []struct {
		metadata            []JSONSafeFA2Metadata
		expectAddedMetadata bool
	}{
		{
			metadata: []JSONSafeFA2Metadata{
				{
					Key:   "",
					Value: "not expected",
				},
				{
					Key:   "foo",
					Value: "bar",
				},
			},
			expectAddedMetadata: false,
		},
		{
			metadata: []JSONSafeFA2Metadata{
				{
					Key:   "foo",
					Value: "bar",
				},
			},
			expectAddedMetadata: true,
		},
	}
	for idx, testcase := range testcases {
		snapshot := FA2Snapshot{
			JSONSafeMetadata: testcase.metadata,
		}

		result, err := snapshot.GetJSONMetadataAsMichelson()

		if err != nil {
			t.Errorf("Got unexpected error on testcase %d: %v", idx, err)
		} else {
			expectedLen := len(testcase.metadata)
			if testcase.expectAddedMetadata {
				expectedLen += 1
			}
			if len(result.Args) != expectedLen {
				t.Errorf("We expected %d items, got %d in testcase %d", expectedLen, len(result.Args), idx)
			}
		}
	}
}

func TestTokenMetadataMarshalling(t *testing.T) {
	testcases := []struct {
		json        string
		expectedLen int
	}{
		{
			json: `
			{
				"token_metadata_bigmap": [
					{
					  "key": 123,
					  "value": {
						"token_id": 123,
						"token_info": {
						  "title": "My project",
						  "url": "http://project.url"
						}
					  }
					}
				]
			}`,
			expectedLen: 1,
		},
		{
			json: `
			{
				"token_metadata_bigmap": [
					{
					  "key": 123,
					  "value": {
						"token_id": 123,
						"token_info": {
						  "title": "My project",
						  "url": "http://project.url"
						}
					  }
					},
					{
					  "key": 58,
					  "value": {
						"token_id": 58,
						"token_info": {
						  "title": "bob",
						  "url": "urlish"
						}
					  }
					}
				]
			}`,
			expectedLen: 2,
		},
		{
			json:        "{}",
			expectedLen: 0,
		},
	}
	for idx, testcase := range testcases {
		var snapshot FA2Snapshot
		err := json.Unmarshal([]byte(testcase.json), &snapshot)
		if err != nil {
			t.Errorf("Failed to unmarshall testcase %d: %v", idx, err)
		}
		if len(snapshot.JSONSafeTokenMetadata) != testcase.expectedLen {
			t.Errorf("Failed to get token metadata from JSON in testcase %d", idx)
		}

		result, err := snapshot.GetJSONTokenMetadataAsMichelson()

		if err != nil {
			t.Errorf("Got unexpected error on testcase %d: %v", idx, err)
		} else {
			if len(result.Args) != testcase.expectedLen {
				t.Errorf("We expected %d items, got %d in testcase %d", testcase.expectedLen, len(result.Args), idx)
			}
			// check the ordering
			lastID := big.NewInt(-1)
			for entryIdx, prim := range result.Args {
				tokenID := prim.Args[0].Int
				if tokenID.Cmp(lastID) != 1 {
					t.Errorf("entry %d of testcase %d is out of order: %v should be less than %v", entryIdx, idx, lastID, tokenID)
				}
				lastID = tokenID
			}
		}
	}
}

func TestLedgerMarshalling(t *testing.T) {
	testcases := []struct{
		json string
		expectedLen int
	}{
		{
			json: `{
				"ledger_bigmap": [
					{
				  		"key": {
							"token_owner": "KT1Jt2kGneGyh4kYB6BcXkdXr4NKqnxg9dMu",
							"token_id": 123
				  		},
				  		"value": 1462
					},
					{
				  		"key": {
							"token_owner": "KT1Jt2kGneGyh4kYB6BcXkdXr4NKqnxg9dMu",
							"token_id": 59
				  		},
				  		"value": 1462
					}
				]
			}`,
			expectedLen: 2,
		},
		{
			json: `{
				"ledger_bigmap": [
					{
					  "key": {
						"token_owner": "KT1Jt2kGneGyh4kYB6BcXkdXr4NKqnxg9dMu",
						"token_id": 123
					  },
					  "value": 1462
					}
				]
			}`,
			expectedLen: 1,
		},
		{
			json: `{
				"ledger_bigmap": []
			}`,
			expectedLen: 0,
		},
	}

	for idx, testcase := range testcases {
		var snapshot FA2Snapshot
		err := json.Unmarshal([]byte(testcase.json), &snapshot)
		if err != nil {
			t.Errorf("Failed to unmarshall testcase %d: %v", idx, err)
		}
		if len(snapshot.JSONSafeLedger) != testcase.expectedLen {
			t.Errorf("Failed to get token ledger from JSON in testcase %d", idx)
		}

		result, err := snapshot.GetJSONLedgerAsMichelson()

		if err != nil {
			t.Errorf("Got unexpected error on testcase %d: %v", idx, err)
		} else {
			if len(result.Args) != testcase.expectedLen {
				t.Errorf("We expected %d items, got %d in testcase %d", testcase.expectedLen, len(result.Args), idx)
			}
			// check the ordering
			lastID := big.NewInt(-1)
			for entryIdx, prim := range result.Args {
				key := prim.Args[0]
				tokenID := key.Args[1].Int
				if tokenID.Cmp(lastID) != 1 {
					t.Errorf("entry %d of testcase %d is out of order: %v should be less than %v", entryIdx, idx, lastID, tokenID)
				}
				lastID = tokenID
			}
		}
	}
}
