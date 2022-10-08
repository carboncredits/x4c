package main

import (
	"fmt"
	"net/http"

    "github.com/julienschmidt/httprouter"

	"quantify.earth/x4c/pkg/tzclient"
)

type server struct {
	mux *httprouter.Router
	tezosClient tzclient.Client
}

func (s *server) getCreditSources(w http.ResponseWriter, r *http.Request, ps httprouter.Params) {
	// In theory we could let through the custodianID as an address, but this stops people using
	// us as a generic Tezos lookup tool
	contract, ok := s.tezosClient.Contracts[ps.ByName("custodianID")]
	if !ok {
		http.Error(w, "Custodian ID not recognised", http.StatusNotFound)
		return
	}

	storage, err := s.tezosClient.GetContractStorage(contract.Address, r.Context())
	if err != nil {
		http.Error(w, "Failed to get contract storage", http.StatusFailedDependency)
		return
	}

	var ledger_id int64 = 0

	switch s := storage.(type) {
	case map[string]interface{}:
		if ledger_raw, ok := s["ledger"]; ok {
			switch ledger := ledger_raw.(type) {
			case int64:
				ledger_id = ledger
			default:
				http.Error(w, "Ledger had wrong type", http.StatusInternalServerError)
				return
			}
		} else {
			http.Error(w, "Failed to find ledger in storage", http.StatusInternalServerError)
			return
		}
	default:
		http.Error(w, "Failed to decode storage", http.StatusInternalServerError)
		return
	}




	fmt.Fprintf(w, "Hello, world! %v", ledger_id)
}



func SetupMyHandlers(client tzclient.Client) server{

	router := httprouter.New()
	server := server{
		mux: router,
		tezosClient: client,
	}

	router.GET("/credit/sources/:custodianID", server.getCreditSources)

// // Sources of credits
// router.get('/credit/sources/:custodianID', controller.getCreditSources);
//
// // Get information about an operation
// router.get('/operation/:opHash', controller.getOperation);
//
// // Get the URL of the indexer that the server is using
// router.get('/info/indexer-url', controller.getIndexerUrl)
//
// // Get information about an operation
// router.get('/operation/events/:opHash', controller.getEvents);
//
// // <><><> POST <><><>
//
// // Retiring a credit using it's ID
// router.post('/retire/:custodianID', controller.retireCredit);

     return server
}

func main() {
	client, err := tzclient.LoadDefaultClient()
	if err != nil {
		panic(err)
	}

     server := SetupMyHandlers(client)
     http.ListenAndServe(":8080", server.mux)
}
