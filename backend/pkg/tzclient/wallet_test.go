package tzclient

import (
	"testing"
)

func TestCreateWalletByAddress(t *testing.T) {
	testcases := []struct {
		address string
		isValid bool
	}{
		{"invalid", false},
		{"tz1TJcX5DuAuH2Fgsx5PpKspXU4G3D7TKxZq", true},
		// Contract is a valid address, but not an ED25519 wallet address
		{"KT1MHx2nw8y2JyryGbuAvTYPNGwrfTp4PEYR", false},
	}
	for index, testcase := range testcases {
		a, err := NewWalletWithAddress("name", testcase.address)
		if testcase.isValid {
			if err != nil {
				t.Errorf("Got unexpected error for case %d: %v", index, err)
			}
			if a.Address.String() != testcase.address {
				t.Errorf("Wallet for case %d has wrong address: %s", index, a.Address.String())
			}
		} else {
			if err == nil {
				t.Errorf("Expected error for case %d, but not none", index)
			}
		}
	}
}

func TestCreateContractByAddress(t *testing.T) {
	testcase := []struct {
		address string
		isValid bool
	}{
		{"invalid", false},
		// This is a valid address, but not an contract address
		{"tz1TJcX5DuAuH2Fgsx5PpKspXU4G3D7TKxZq", false},
		{"KT1MHx2nw8y2JyryGbuAvTYPNGwrfTp4PEYR", true},
	}
	for index, testcase := range testcase {
		c, err := NewContractWithAddress("name", testcase.address)
		if testcase.isValid {
			if err != nil {
				t.Errorf("Got unexpected error for case %d: %v", index, err)
			}
			if c.Address.String() != testcase.address {
				t.Errorf("Wallet for case %d has wrong address: %s", index, c.Address.String())
			}
		} else {
			if err == nil {
				t.Errorf("Expected error for case %d, but not none", index)
			}
		}
	}
}
