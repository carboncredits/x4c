package main

import (
	"encoding/json"
	"fmt"
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
		Data: s.tezosClient.IndexerWebURL,
	}

	err := json.NewEncoder(w).Encode(response)
	if err != nil {
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}
}

func (s *server) getOperation(w http.ResponseWriter, r *http.Request, ps httprouter.Params) {
	hash := ps.ByName("opHash")
	if hash == "" {
		http.Error(w, "Failed to find operation hash", http.StatusBadRequest)
		return
	}

	operations, err := s.tezosClient.GetOperationInformation(r.Context(), hash)

	response := GetOperationResponse{
		Data: operations,
	}

	err = json.NewEncoder(w).Encode(response)
	if err != nil {
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}
}

func (s *server) getEvents(w http.ResponseWriter, r *http.Request, ps httprouter.Params) {
	contractAddress := ps.ByName("contractHash")
	_, err := tzclient.NewContractWithAddress("contract", contractAddress)
	if err != nil {
		http.Error(w, "Failed parse contract address", http.StatusBadRequest)
		return
	}

	tag := ps.ByName("tag")
	if tag == "" {
		http.Error(w, "Failed to find tag", http.StatusBadRequest)
		return
	}

	events, err := s.tezosClient.GetContractEvents(r.Context(), contractAddress, tag)
	if err != nil {
		fmt.Printf("%v\n", err)
		http.Error(w, "Failed to get events", http.StatusInternalServerError)
		return
	}

	response := GetEventsResponse{
		Data: events,
	}

	err = json.NewEncoder(w).Encode(response)
	if err != nil {
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}
}
