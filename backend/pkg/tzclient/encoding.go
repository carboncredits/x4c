package tzclient

import (
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"strings"

	"blockwatch.cc/tzgo/micheline"
)

func MichelsonToString(raw string) (string, error) {
	if !strings.HasPrefix(raw, "0501") {
		return "", fmt.Errorf("michelson prefix not found")
	}

	bytes, err := hex.DecodeString(raw)
	if err != nil {
		return "", fmt.Errorf("failed to decode michelson to bytes: %w", err)
	}

	// first byte should be 05
	// second byte should be 01
	// next four bytes are length
	// remainder is string data
	if len(bytes) <= 6 {
		return "", fmt.Errorf("michelson data too short")
	}
	length := binary.BigEndian.Uint32(bytes[2:6])
	if (length + 6) != uint32(len(bytes)) {
		return "", fmt.Errorf("length mismatch: expected %d bytes of payload, have %d", length, len(bytes)-6)
	}
	payload := bytes[6:]

	return string(payload), nil
}

func StringToMichelson(raw string) (string, error) {
	prim := micheline.NewString(raw)
	data, err := prim.MarshalBinary()
	if err != nil {
		return "", fmt.Errorf("failed to marshall string: %w", err)
	}
	return "05" + hex.EncodeToString(data), nil
}
