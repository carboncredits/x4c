package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/http/httputil"
	"testing"

	"quantify.earth/x4c/pkg/tzclient"
	"quantify.earth/x4c/pkg/tzkt"
	"quantify.earth/x4c/pkg/x4c"
)

func TestGetCreditSources(t *testing.T) {

	mockClient := tzclient.NewMockClient()
	item := tzkt.BigMapItem{
		Active: true,
		Key:    json.RawMessage(`{"token": {"token_id": 42, "token_address": "tz1deC7DBmyTU7DtfV7f4YmpbW3xQkBYEwVB"}, "kyc": "0501000000096f74686572206f7267"}`),
		Value:  json.RawMessage(`1234`),
	}
	items := make([]tzkt.BigMapItem, 1)
	items[0] = item
	mockClient.AddBigMap(1234, items)

	testcases := []struct {
		custodian     string
		bigmapID      int64
		expectSuccess bool
		expectData    bool
	}{
		{
			custodian:     "",
			bigmapID:      0,
			expectSuccess: false,
			expectData:    false,
		},
		{
			custodian:     "KT1Lw1p7rDaZixeX1SpmdNAueWW3QihZ31C6",
			bigmapID:      1234,
			expectSuccess: true,
			expectData:    true,
		},
		{
			custodian:     "KT1Lw1p7rDaZixeX1SpmdNAueWW3QihZ31C6",
			bigmapID:      1235,
			expectSuccess: true,
			expectData:    false,
		},
		{
			custodian:     "alice",
			bigmapID:      0,
			expectSuccess: false,
			expectData:    false,
		},
	}

	for idx, testcase := range testcases {

		custodianStorage := x4c.CustodianStorage{
			Ledger: testcase.bigmapID,
		}
		mockClient.Storage = &custodianStorage
		server := newMockServer(mockClient)

		url := fmt.Sprintf("/credit/sources/%s", testcase.custodian)
		r, err := http.NewRequest("GET", url, nil)
		if err != nil {
			t.Fatal(err)
		}
		w := httptest.NewRecorder()
		server.mux.ServeHTTP(w, r)

		resp := w.Result()
		defer func() {
			resp.Body.Close()
		}()

		if testcase.expectSuccess {
			if resp.StatusCode != http.StatusOK {
				respDump, _ := httputil.DumpResponse(resp, true)
				t.Errorf("%d: Unexpected status code %d. Body was: %v", idx, resp.StatusCode, string(respDump))
			} else {
				var result CreditSourcesResponse
				decoder := json.NewDecoder(resp.Body)
				decoder.DisallowUnknownFields()
				err = decoder.Decode(&result)
				if err != nil {
					t.Errorf("%d: failed to decode response: %v", idx, err)
				} else {
					if testcase.expectData && len(result.Data) == 0 {
						t.Errorf("%d: Expected data, but got none", idx)
					}
					if testcase.expectData && len(result.Data) > 0 {
						source := result.Data[0]
						// This relies on the mock server configuration, if that changes this test will fail.
						if source.CustodainURL != "https://index.web/KT1Lw1p7rDaZixeX1SpmdNAueWW3QihZ31C6" {
							t.Errorf("Unexpected CustodianURL: %s", source.CustodainURL)
						}
						if source.Amount != 1234 {
							t.Errorf("Unexpected amount: %v", source.Amount)
						}
					}
					if !testcase.expectData && len(result.Data) != 0 {
						t.Errorf("%d: Expected no data, but got some: %v", idx, result.Data)
					}
				}
			}
		} else {
			if resp.StatusCode == http.StatusOK {
				respDump, _ := httputil.DumpResponse(resp, true)
				t.Errorf("%d: Unexpected status code %d. Body was: %v", idx, resp.StatusCode, string(respDump))
			}
		}
	}
}
