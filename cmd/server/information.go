package main

import (
	"encoding/json"
	"net/http"

	"github.com/julienschmidt/httprouter"

	"quantify.earth/x4c/pkg/tzkt"
)

type GetIndexerURLResponse struct {
	Data string `json:"data"`
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

type GetOperationResponse struct {
	Data []tzkt.Operation `json:"data"`
}

func (s *server) getOperation(w http.ResponseWriter, r *http.Request, ps httprouter.Params) {
	hash := ps.ByName("opHash")

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
