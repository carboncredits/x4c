package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/http/httputil"
	"testing"

	"quantify.earth/x4c/pkg/tzclient"
)

func TestRetire(t *testing.T) {
	client := tzclient.NewMockClient()
	server := newMockServer(client)

	testcases := []struct {
		contract      string
		expectSuccess bool
		amount        json.Number
	}{
		{
			contract:      "alice",
			expectSuccess: false,
			amount:        "123",
		},
		{
			contract:      "KT1QjwDCohN4BEewsWgzkQHLsrv1Sf3s2PCm",
			expectSuccess: true,
			amount:        "123",
		},
		{
			contract:      "KT1QjwDCohN4BEewsWgzkQHLsrv1Sf3s2PCm",
			expectSuccess: false,
			amount:        "0",
		},
		{
			contract:      "KT1QjwDCohN4BEewsWgzkQHLsrv1Sf3s2PCm",
			expectSuccess: false,
			amount:        "-123",
		},
		{
			contract:      "KT1QjwDCohN4BEewsWgzkQHLsrv1Sf3s2PCm",
			expectSuccess: false,
			amount:        "3.14",
		},
	}

	for idx, testcase := range testcases {

		request := CreditRetireRequest{
			Minter:  "KT1MHx2nw8y2JyryGbuAvTYPNGwrfTp4PEYR",
			KYC:     "compsci",
			TokenID: "123",
			Amount:  testcase.amount,
			Reason:  "fun",
		}
		requestBody, err := json.Marshal(request)
		if err != nil {
			t.Fatal(err)
		}

		url := fmt.Sprintf("/contract/%s/retire", testcase.contract)
		r, err := http.NewRequest("POST", url, bytes.NewBuffer(requestBody))
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
			}

			var result CreditRetireResponse
			decoder := json.NewDecoder(resp.Body)
			decoder.DisallowUnknownFields()
			err = decoder.Decode(&result)
			if err != nil {
				t.Errorf("%d: Failed to decode response: %v", idx, err)
			} else {
				if result.Data.Message != "Successfully retired credits" {
					t.Errorf("%d: Did not get expected message: %v", idx, result.Data)
				}
				if result.Data.OperationHash != "operationHash" {
					t.Errorf("%d: Did not get expected operation hash: %v", idx, result.Data)
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
