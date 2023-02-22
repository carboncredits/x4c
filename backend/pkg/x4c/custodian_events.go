package x4c

import (
	"context"
	"encoding/json"
	"fmt"

	"quantify.earth/x4c/pkg/tzclient"
	"quantify.earth/x4c/pkg/tzkt"
)

type CustodianRetireEvent struct {
	tzkt.Event
	RetiringParty       string      `json:"retiring_party"`
	RetiringPartyKyc string      `json:"retiring_party_kyc"`
	Token               TokenID     `json:"token"`
	Amount              json.Number `json:"amount"`
	Reason           string      `json:"retiring_data"`
}

type InternalMintEvent struct {
	tzkt.Event
	Token    TokenID     `json:"token"`
	Amount   json.Number `json:"amount"`
	NewTotal json.Number `json:"new_total"`
}

type InternalTransferEvent struct {
	tzkt.Event
	RawTo   string      `json:"source"`
	RawFrom string      `json:"destination"`
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
		typedEvent := CustodianRetireEvent{
		    event,
		    "",
		    "",
		    TokenID{},
		    "0",
		    "",
		}
		err = json.Unmarshal(event.Payload, &typedEvent)
		if err != nil {
			return nil, fmt.Errorf("failed to unmarshall payload: %w", err)
		}
        retiring_party_kyc, err := tzclient.MichelsonToString(typedEvent.RetiringPartyKyc)
        if err != nil {
            return nil, fmt.Errorf("failed to unmarshall event retiring_party_kyc: %w", err)
        }
        typedEvent.RetiringPartyKyc = retiring_party_kyc
        reason, err := tzclient.MichelsonToString(typedEvent.Reason)
        if err != nil {
            return nil, fmt.Errorf("failed to unmarshall event reason: %w", err)
        }
        typedEvent.Reason = reason

		result[idx] = typedEvent
	}
	return result, nil
}

func GetInternalTransferEvents(ctx context.Context, client tzclient.TezosClient, contract tzclient.Contract) ([]InternalTransferEvent, error) {
	raw, err := client.GetContractEvents(ctx, contract.Address.String(), "internal_transfer")
	if err != nil {
		return nil, fmt.Errorf("failed to find internal_transfer events: %w", err)
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
		return nil, fmt.Errorf("failed to find internal_mint events: %w", err)
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
