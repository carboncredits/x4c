package main

import (
	"net/http"

	"github.com/julienschmidt/httprouter"

	"quantify.earth/x4c/pkg/tzclient"
)

type server struct {
	mux         *httprouter.Router
	tezosClient tzclient.Client
}

func SetupMyHandlers(client tzclient.Client) server {

	router := httprouter.New()
	server := server{
		mux:         router,
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
