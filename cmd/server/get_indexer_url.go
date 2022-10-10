package main

import (
	"encoding/json"
	"net/http"

	"github.com/julienschmidt/httprouter"
)

type GetIndexerURL struct {
	Data string `json:"data"`
}

func (s *server) getIndexerURL(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
	response := GetIndexerURL{
		Data: s.tezosClient.IndexerWebURL,
	}

	err := json.NewEncoder(w).Encode(response)
	if err != nil {
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}
}
