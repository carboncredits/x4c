package x4c

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"fmt"

	"quantify.earth/x4c/pkg/tzclient"
	"quantify.earth/x4c/pkg/tzkt"
)

type FA2RetireEvent struct {
	tzkt.Event
	Reason string
}

func GetFA2RetireEvents(ctx context.Context, client tzclient.TezosClient, contract tzclient.Contract) ([]FA2RetireEvent, error) {
	raw, err := client.GetContractEvents(ctx, contract.Address.String(), "retire")
	if err != nil {
		return nil, fmt.Errorf("failed to find retire events: %w", err)
	}

	result := make([]FA2RetireEvent, len(raw))
	for idx, event := range raw {
		var rawPayload string
		err = json.Unmarshal(event.Payload, &rawPayload)
		if err != nil {
			return nil, fmt.Errorf("failed to unmarshall payload: %w", err)
		}
		data, err := hex.DecodeString(rawPayload)
		if err != nil {
			return nil, fmt.Errorf("failed to decode payload: %w", err)
		}
		typedEvent := FA2RetireEvent{
			event,
			string(data),
		}
		result[idx] = typedEvent
	}
	return result, nil
}
