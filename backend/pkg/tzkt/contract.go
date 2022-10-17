package tzkt

import (
	"context"
	"encoding/json"
	"fmt"
	"time"
)

type EventContractInfo struct {
	Address *string `json:"address,omitempty"`
	Alias   *string `json:"alias,omitempty"`
}

type Event struct {
	Identifier    int64             `json:"id"`
	Level         int32             `json:"level"`
	Timestamp     time.Time         `json:"timestamp"`
	Contract      EventContractInfo `json:"contract"`
	CodeHash      int32             `json:"codeHash"`
	Tag           string            `json:"tag"`
	Payload       json.RawMessage   `json:"payload"`
	TransactionID int64             `json:"transactionId"`
}

func (c *TzKTClient) GetContractStorage(ctx context.Context, contractAddress string, storage interface{}) error {
	path := fmt.Sprintf("/v1/contracts/%s/storage", contractAddress)
	err := c.makeRequest(ctx, path, storage)
	if err != nil {
		return fmt.Errorf("failed to make request: %w", err)
	}
	return nil
}

func (c *TzKTClient) GetContractEvents(ctx context.Context, contractAddress string, tag string) ([]Event, error) {
	path := fmt.Sprintf("/v1/contracts/events?contract=%s&tag=%s", contractAddress, tag)

	var results []Event
	err := c.makeRequest(ctx, path, &results)
	if err != nil {
		return nil, fmt.Errorf("failed to make event request: %w", err)
	}
	return results, nil
}
