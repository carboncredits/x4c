package tzclient

import (
	"encoding/hex"

	"blockwatch.cc/tzgo/micheline"
)

func MichelsonToString(raw string) (string, error) {
	bytes, err := hex.DecodeString(raw)
	if err != nil {
		return "", err
	}
	prim := micheline.NewBytes(bytes)
	unpacked, err := prim.Unpack()
	if err != nil {
		return "", err
	}
	return unpacked.String, nil
}
