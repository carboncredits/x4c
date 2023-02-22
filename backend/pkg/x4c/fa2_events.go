package x4c

import (
	"context"
	"encoding/json"
	"fmt"

	"quantify.earth/x4c/pkg/tzclient"
	"quantify.earth/x4c/pkg/tzkt"
)

type FA2RetireEvent struct {
	tzkt.Event
	RetiringParty       string      `json:"retiring_party"`
	TokenID             json.Number `json:"tokenId"`
	Amount              json.Number `json:"amount"`
	Reason              string      `json:"retiring_data"`
}

func GetFA2RetireEvents(ctx context.Context, client tzclient.TezosClient, contract tzclient.Contract) ([]FA2RetireEvent, error) {
	raw, err := client.GetContractEvents(ctx, contract.Address.String(), "retire")
	if err != nil {
		return nil, fmt.Errorf("failed to find retire events: %w", err)
	}

	result := make([]FA2RetireEvent, len(raw))
	for idx, event := range raw {
		typedEvent := FA2RetireEvent {
			event,
			"",
			"0",
			"0",
			"",
		}
		err = json.Unmarshal(event.Payload, &typedEvent)
		if err != nil {
			return nil, fmt.Errorf("failed to unmarshall payload: %w", err)
		}
		reason, err := tzclient.MichelsonToString(typedEvent.Reason)
		if err != nil {
			return nil, fmt.Errorf("failed to unmarshall event reason: %w", err)
		}
		typedEvent.Reason = reason
		result[idx] = typedEvent
	}
	return result, nil
}
