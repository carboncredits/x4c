package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"

	"github.com/julienschmidt/httprouter"

	"quantify.earth/x4c/pkg/tzclient"
	"quantify.earth/x4c/pkg/tzkt"
)

type GetIndexerURLResponse struct {
	Data string `json:"data"`
}

type GetOperationResponse struct {
	Data []tzkt.Operation `json:"data"`
}

type GetEventsResponse struct {
	Data []tzkt.Event `json:"data"`
}

func (s *server) getIndexerURL(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
	response := GetIndexerURLResponse{
		Data: s.tezosClient.GetIndexerWebURL(),
	}

	err := json.NewEncoder(w).Encode(response)
	if err != nil {
		log.Printf("Failed to encode get indexer response: %v", err)
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}
}

func (s *server) getOperation(w http.ResponseWriter, r *http.Request, ps httprouter.Params) {
	hash := ps.ByName("opHash")
	if hash == "" {
		http.Error(w, "No operation hash specified", http.StatusBadRequest)
		return
	}

	operations, err := s.tezosClient.GetOperationInformation(r.Context(), hash)
	if err != nil {
		log.Printf("Error when lookup up operation %s: %v", hash, err)
		http.Error(w, "Failed to look up operation", http.StatusInternalServerError)
		return
	}

	response := GetOperationResponse{
		Data: operations,
	}

	err = json.NewEncoder(w).Encode(response)
	if err != nil {
		log.Printf("Failed to encode get operation response: %v", err)
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}
}

func (s *server) getEvents(w http.ResponseWriter, r *http.Request, ps httprouter.Params) {
	contractAddress := ps.ByName("contractHash")
	if contractAddress == "" {
		http.Error(w, "No contract hash specified", http.StatusBadRequest)
		return
	}
	_, err := tzclient.NewContractWithAddress("contract", contractAddress)
	if err != nil {
		err_str := fmt.Sprintf("Failed to parse contract address: %v", err)
		http.Error(w, err_str, http.StatusBadRequest)
		return
	}

	tag := ps.ByName("tag")
	if tag == "" {
		http.Error(w, "No tag specified", http.StatusBadRequest)
		return
	}

	events, err := s.tezosClient.GetContractEvents(r.Context(), contractAddress, tag)
	if err != nil {
		log.Printf("Failed to lookup events tagged %s on %s: %v\n", tag, contractAddress, err)
		http.Error(w, "Failed to get events", http.StatusInternalServerError)
		return
	}

	response := GetEventsResponse{
		Data: events,
	}

	err = json.NewEncoder(w).Encode(response)
	if err != nil {
		log.Printf("Failed to encode get events response: %v", err)
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}
}
