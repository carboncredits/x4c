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

type CreditRetireRequest struct {
	Minter  string      `json:"minter"`
	KYC     string      `json:"kyc"`
	TokenID json.Number `json:"tokenID"`
	Amount  json.Number `json:"amount"`
	Reason  string      `json:"reason"`
}

type CreditRetireResponse struct {
	Message            string `json:"message"`
	OperationHash      string `json:"updateHash"`
	OperationLookupURL string `json:"tzstatsUpdateHashUrl"`
}

func (s *server) retire(w http.ResponseWriter, r *http.Request, ps httprouter.Params) {

	contract_address := ps.ByName("contractHash")
	if contract_address == "" {
		http.Error(w, "No contract address specified", http.StatusBadRequest)
		return
	}
	contract, ok := s.tezosClient.Contracts[contract_address]
	if !ok {
		var err error
		contract, err = tzclient.NewContractWithAddress("contract", contract_address)
		if err != nil {
			http.Error(w, "Failed parse contract address", http.StatusBadRequest)
			return
		}
	}

	body := http.MaxBytesReader(w, r.Body, 1048576)
	decoder := json.NewDecoder(body)
	decoder.DisallowUnknownFields()

	var request CreditRetireRequest
	err := decoder.Decode(&request)
	if err != nil {
		http.Error(w, "Failed to decode request", http.StatusBadRequest)
		return
	}

	minter, ok := s.tezosClient.Contracts[request.Minter]
	if !ok {
		minter, err = tzclient.NewContractWithAddress("minter", request.Minter)
		if err != nil {
			err_str := fmt.Sprintf("Failed to resolve minter: %v", err)
			http.Error(w, err_str, http.StatusBadRequest)
			return
		}
	}

	token_id, err := request.TokenID.Int64()
	if err != nil {
		err_str := fmt.Sprintf("Failed to resolve token ID: %v", err)
		http.Error(w, err_str, http.StatusBadRequest)
		return
	}

	amount, err := request.Amount.Int64()
	if err != nil {
		err_str := fmt.Sprintf("Failed to resolve amount: %v", err)
		http.Error(w, err_str, http.StatusBadRequest)
		return
	}

	op_hash, err := x4c.CustodianRetire(r.Context(), s.tezosClient, contract, s.custodianOperator, minter, token_id, request.KYC, amount, request.Reason)
	if err != nil {
		err_str := fmt.Sprintf("Failed call contract: %v", err)
		http.Error(w, err_str, http.StatusInternalServerError)
		return
	}

	result := CreditRetireResponse{
		Message:            "Successfully retired credits",
		OperationHash:      op_hash,
		OperationLookupURL: s.tezosClient.IndexerWebURL + "/" + op_hash,
	}
	err = json.NewEncoder(w).Encode(result)
	if err != nil {
		log.Printf("Failed to encode get retire response: %v", err)
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}
}
