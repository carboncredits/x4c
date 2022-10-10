package x4c

import (
	"encoding/json"
)

type CustodianContract struct {
	address string
}

type TokenID struct {
	TokenID json.Number  `json:"token_id"`
	Address string `json:"token_address"`
}

type LedgerKey struct {
	Token TokenID `json:"token"`
	KYC   string  `json:"kyc"`
}

type Ledger map[LedgerKey]int64

type BigMapIdentifier int64

type CustodianStorage struct {
	Ledger         BigMapIdentifier `json:"ledger"`
	Metadata       BigMapIdentifier `json:"metadata"`
	Custodian      string           `json:"custodian"`
	Operators      []string         `json:"operators"`
	ExternalLedger BigMapIdentifier `json:"external_ledger"`
}

func (c *CustodianContract) GetStorage() {

}
