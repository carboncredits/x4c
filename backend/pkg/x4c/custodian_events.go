package x4c

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"fmt"

	"quantify.earth/x4c/pkg/tzclient"
	"quantify.earth/x4c/pkg/tzkt"
)

type CustodianRetireEvent struct {
	tzkt.Event
	Reason string
}

type InternalMintEvent struct {
	tzkt.Event
	Token    TokenID     `json:"token"`
	Amount   json.Number `json:"amount"`
	NewTotal json.Number `json:"new_total"`
}

type InternalTransferEvent struct {
	tzkt.Event
	RawTo   string      `json:"to"`
	RawFrom string      `json:"from"`
	Token   TokenID     `json:"token"`
	Amount  json.Number `json:"amount"`
}

func (e InternalTransferEvent) To() string {
	res, err := tzclient.MichelsonToString(e.RawTo)
	if err != nil {
		return e.RawTo
	}
	return res
}

func (e InternalTransferEvent) From() string {
	res, err := tzclient.MichelsonToString(e.RawFrom)
	if err != nil {
		return e.RawFrom
	}
	return res
}

func GetCustodianRetireEvents(ctx context.Context, client tzclient.TezosClient, contract tzclient.Contract) ([]CustodianRetireEvent, error) {
	raw, err := client.GetContractEvents(ctx, contract.Address.String(), "retire")
	if err != nil {
		return nil, fmt.Errorf("failed to find retire events: %w", err)
	}

	result := make([]CustodianRetireEvent, len(raw))
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
		typedEvent := CustodianRetireEvent{
			event,
			string(data),
		}
		result[idx] = typedEvent
	}
	return result, nil
}

func GetInternalTransferEvents(ctx context.Context, client tzclient.TezosClient, contract tzclient.Contract) ([]InternalTransferEvent, error) {
	raw, err := client.GetContractEvents(ctx, contract.Address.String(), "internal_transfer")
	if err != nil {
		return nil, fmt.Errorf("failed to find retire events: %w", err)
	}

	result := make([]InternalTransferEvent, len(raw))
	for idx, event := range raw {
		typedEvent := InternalTransferEvent{
			event,
			"",
			"",
			TokenID{},
			"0",
		}
		err = json.Unmarshal(event.Payload, &typedEvent)
		if err != nil {
			return nil, fmt.Errorf("failed to unmarshall internal transfer payload: %w", err)
		}
		result[idx] = typedEvent
	}
	return result, nil
}

func GetInternalMintEvents(ctx context.Context, client tzclient.TezosClient, contract tzclient.Contract) ([]InternalMintEvent, error) {
	raw, err := client.GetContractEvents(ctx, contract.Address.String(), "internal_mint")
	if err != nil {
		return nil, fmt.Errorf("failed to find retire events: %w", err)
	}

	result := make([]InternalMintEvent, len(raw))
	for idx, event := range raw {
		typedEvent := InternalMintEvent{
			event,
			TokenID{},
			"0",
			"0",
		}
		err = json.Unmarshal(event.Payload, &typedEvent)
		if err != nil {
			return nil, fmt.Errorf("failed to unmarshall internal mint payload: %w", err)
		}
		result[idx] = typedEvent
	}
	return result, nil
}
