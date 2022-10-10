package main

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/julienschmidt/httprouter"

	"quantify.earth/x4c/pkg/x4c"
)

type CreditSourcesResponseItem struct {
	TokenID      int64  `json:"tokenId"`
	MinterURL    string `json:"tzstatsMinterUrl"` // `${indexerUrl}/${entry.token_id}`,
	KYC          string `json:"kyc"`
	CustodainURL string `json:"tzstatsCustodianUrl"` // `${indexerUrl}/${custodian.contract.address}`,
	Amount       int64  `json:"amount"`
	Minter       string `json:"minter"`
}

type CreditSourcesResponse struct {
	Data []CreditSourcesResponseItem `json:"data"`
}

func (s *server) getCreditSources(w http.ResponseWriter, r *http.Request, ps httprouter.Params) {
	// In theory we could let through the custodianID as an address, but this stops people using
	// us as a generic Tezos lookup tool
	contract, ok := s.tezosClient.Contracts[ps.ByName("custodianID")]
	if !ok {
		http.Error(w, "Custodian ID not recognised", http.StatusNotFound)
		return
	}

	var storage x4c.CustodianStorage
	err := s.tezosClient.GetContractStorage(contract.Address, r.Context(), &storage)
	if err != nil {
		http.Error(w, "Failed to get contract storage", http.StatusFailedDependency)
		return
	}

	ledger, err := storage.GetLedger(r.Context(), s.tezosClient)
	if err != nil {
		http.Error(w, "Failed to get ledger storage", http.StatusInternalServerError)
		return
	}

	results := make([]CreditSourcesResponseItem, 0, len(ledger))
	for key, value := range ledger {
		token_id, err := key.Token.TokenID.Int64()
		if err != nil {
			http.Error(w, "Failed to convert token ID", http.StatusInternalServerError)
			return
		}

		item := CreditSourcesResponseItem{
			TokenID:      token_id,
			MinterURL:    fmt.Sprintf("%s%s", s.tezosClient.IndexerWebURL, key.Token.Address),
			KYC:          key.KYC,
			CustodainURL: fmt.Sprintf("%s%s", s.tezosClient.IndexerWebURL, contract.Address),
			Amount:       value,
			Minter:       key.Token.Address,
		}
		results = append(results, item)
	}

	response := CreditSourcesResponse{
		Data: results,
	}

	err = json.NewEncoder(w).Encode(response)
	if err != nil {
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}
}
