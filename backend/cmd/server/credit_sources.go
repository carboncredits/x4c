package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"

	"github.com/julienschmidt/httprouter"

	"quantify.earth/x4c/pkg/tzclient"
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
	custodian_address := ps.ByName("custodianID")
	if custodian_address == "" {
		http.Error(w, "No custodian ID specified", http.StatusBadRequest)
		return
	}
	contract, err := s.tezosClient.ContractByName(custodian_address)
	if err != nil {
		contract, err = tzclient.NewContractWithAddress("custodian", custodian_address)
		if err != nil {
			http.Error(w, "Custodian ID not recognised", http.StatusBadRequest)
			return
		}
	}

	var storage x4c.CustodianStorage
	err = s.tezosClient.GetContractStorage(contract, r.Context(), &storage)
	if err != nil {
		log.Printf("Failed to lookup contract storage for %s: %v", custodian_address, err)
		http.Error(w, "Failed to get contract storage", http.StatusFailedDependency)
		return
	}

	ledger, err := storage.GetLedger(r.Context(), s.tezosClient)
	if err != nil {
		log.Printf("Failed to lookup contract ledger (%d) %s: %v", storage.Ledger, custodian_address, err)
		http.Error(w, "Failed to get ledger storage", http.StatusInternalServerError)
		return
	}

	results := make([]CreditSourcesResponseItem, 0, len(ledger))
	for key, value := range ledger {
		token_id, err := key.Token.TokenID.Int64()
		if err != nil {
			log.Printf("Failed to convert token ID %v to int64: %v", key.Token.TokenID, err)
			http.Error(w, "Failed to convert token ID", http.StatusInternalServerError)
			return
		}

		kyc, err := key.DecodeKYC()
		if err != nil {
			kyc = key.RawKYC
		}
		indexerURL := s.tezosClient.GetIndexerWebURL()
		item := CreditSourcesResponseItem{
			TokenID:      token_id,
			MinterURL:    fmt.Sprintf("%s/%s", indexerURL, key.Token.Address),
			KYC:          kyc,
			CustodainURL: fmt.Sprintf("%s/%s", indexerURL, contract.Address.String()),
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
		log.Printf("Failed to encode credit sources response: %v", err)
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}
}
