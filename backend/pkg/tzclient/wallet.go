package tzclient

import (
	"fmt"

	"blockwatch.cc/tzgo/tezos"
)

type Addressable interface {
	Address() tezos.Address
}

type Wallet struct {
	Name    string
	Address tezos.Address
	Key     *tezos.PrivateKey
}

func NewWalletWithAddress(name string, address string) (Wallet, error) {
	tezos_address, err := tezos.ParseAddress(address)
	if err != nil {
		return Wallet{}, err
	}
	// we should support more types for this, rather than just tz1
	if tezos_address.Type != tezos.AddressTypeEd25519 {
		return Wallet{}, fmt.Errorf("invalid wallet address")
	}
	return Wallet{
		Name:    name,
		Address: tezos_address,
	}, nil
}

func NewWalletWithPrivateKey(name string, private_key string) (Wallet, error) {
	tezos_private_key, err := tezos.ParsePrivateKey(private_key)
	if err != nil {
		return Wallet{}, err
	}
	return Wallet{
		Name:    name,
		Address: tezos_private_key.Address(),
		Key:     &tezos_private_key,
	}, nil
}

type Contract struct {
	Name    string
	Address tezos.Address
}

func NewContractWithAddress(name string, address string) (Contract, error) {
	tezos_address, err := tezos.ParseAddress(address)
	if err != nil {
		return Contract{}, err
	}
	if tezos_address.Type != tezos.AddressTypeContract {
		return Contract{}, fmt.Errorf("invalid contract address")
	}
	return Contract{
		Name:    name,
		Address: tezos_address,
	}, nil
}
