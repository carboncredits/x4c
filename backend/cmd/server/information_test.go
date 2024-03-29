package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/http/httputil"
	"testing"

	"quantify.earth/x4c/pkg/tzclient"
)

func newMockServer(client tzclient.MockClient) server {
	operator, _ := tzclient.NewWalletWithAddress("operator", "tz1bWfY2RfUMCgjrSooaFuXfGpMCwUzJL7P5")
	server := SetupMyHandlers(client, operator)
	return server
}

func TestGetIndexerURL(t *testing.T) {
	client := tzclient.NewMockClient()
	server := newMockServer(client)

	r, err := http.NewRequest("GET", "/info/indexer-url", nil)
	if err != nil {
		t.Fatal(err)
	}
	w := httptest.NewRecorder()
	server.mux.ServeHTTP(w, r)

	resp := w.Result()
	defer func() {
		resp.Body.Close()
	}()

	if resp.StatusCode != http.StatusOK {
		respDump, _ := httputil.DumpResponse(resp, true)
		t.Errorf("Unexpected status code %d. Body was: %v", resp.StatusCode, string(respDump))
	}

	var result GetIndexerURLResponse
	decoder := json.NewDecoder(resp.Body)
	decoder.DisallowUnknownFields()
	err = decoder.Decode(&result)
	if err != nil {
		t.Errorf("failed to decode response: %v", err)
	} else if result.Data != server.tezosClient.GetIndexerWebURL() {
		t.Errorf("We did not get the expected response (%v): %v", server.tezosClient.GetIndexerWebURL(), result.Data)
	}
}
