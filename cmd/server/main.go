package main

import (
	"log"
	"net/http"
	"os"

	"github.com/julienschmidt/httprouter"

	"quantify.earth/x4c/pkg/tzclient"
)

type server struct {
	mux               *httprouter.Router
	tezosClient       tzclient.Client
	custodianOperator tzclient.Wallet
}

func SetupMyHandlers(client tzclient.Client) server {

	router := httprouter.New()
	server := server{
		mux:         router,
		tezosClient: client,
	}

	router.GET("/credit/sources/:custodianID", server.getCreditSources)
	router.GET("/operation/:opHash", server.getOperation)
	router.GET("/info/indexer-url", server.getIndexerURL)
	router.GET("/contract/:contractHash/events/:tag", server.getEvents)
	router.POST("/contact/:contractHash/retire", server.retire)

	// legacy API endpoints for compatibility
	router.POST("/retire/:contractHash", server.retire)

	return server
}

func main() {
	client, err := tzclient.LoadDefaultClient()
	if err != nil {
		log.Printf("Failed to load tezos client info: %v", err)
		os.Exit(1)
	}

	operator_name := os.Getenv("CUSTODIAN_OPERATOR")
	if operator_name == "" {
		log.Printf("No operator specified (use env var CUSTODIAN_OPERATOR)")
		os.Exit(1)
	}
	operator, ok := client.Wallets[operator_name]
	if !ok {
		log.Printf("Failed to find wallet for %s", operator)
		os.Exit(1)
	}

	server := SetupMyHandlers(client)
	server.custodianOperator = operator
	http.ListenAndServe(":8080", server.mux)
}
