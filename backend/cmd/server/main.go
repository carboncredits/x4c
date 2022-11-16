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
	tezosClient       tzclient.TezosClient
	custodianOperator tzclient.Wallet
}

func SetupMyHandlers(client tzclient.TezosClient, operator tzclient.Wallet) server {

	router := httprouter.New()
	server := server{
		mux:               router,
		tezosClient:       client,
		custodianOperator: operator,
	}

	router.GET("/credit/sources/:custodianID", server.getCreditSources)
	router.GET("/operation/:opHash", server.getOperation)
	router.GET("/info/indexer-url", server.getIndexerURL)
	router.GET("/contract/:contractHash/events/:tag", server.getEvents)
	router.POST("/contract/:contractHash/retire", server.retire)

	// legacy API endpoints for compatibility
	router.POST("/retire/:contractHash", server.retire)

	return server
}

func main() {
	client, err := tzclient.NewClient()
	if err != nil {
		log.Printf("Failed to load tezos client info: %v", err)
		os.Exit(1)
	}

	log.Printf("Tezos RPC URL: %v\n", client.RPCURL)
	log.Printf("Indexer RPC URL: %v\n", client.IndexerRPCURL)
	log.Printf("Indexer Web URL: %v\n", client.GetIndexerWebURL())
	log.Printf("Signatory URL: %v\n", client.SignatoryURL)

	operator_name := os.Getenv("CUSTODIAN_OPERATOR")
	if operator_name == "" {
		log.Printf("No operator specified (use env var CUSTODIAN_OPERATOR)")
		os.Exit(1)
	}
	operator, ok := client.Wallets[operator_name]
	if !ok {
		// if not there, we assume we're using a yubikey/signatory setup, so
		// let us manually add the Wallet for now.
		operator, err = tzclient.NewWalletWithAddress("operator", operator_name)
		if err != nil {
			log.Printf("Unable to add wallet with address %v", operator_name)
			os.Exit(1)
		}
	}
	log.Printf("Operator address: %v\n", operator.Address.String())

	server := SetupMyHandlers(client, operator)
	http.ListenAndServe(":8080", server.mux)
}
