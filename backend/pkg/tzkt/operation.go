package tzkt

import (
	"context"
	"encoding/json"
	"fmt"
	"time"
)

type Operation struct {
	Type       string          `json:"type"`
	Identifier int64           `json:"id"`
	Level      int32           `json:"level"`
	Timestamp  time.Time       `json:"timestamp"`
	Block      string          `json:"block"`
	Hash       string          `json:"hash"`
	Delegate   json.RawMessage `json:"delegate,omitempty"`
	Parameter  json.RawMessage `json:"parameter,omitempty"`
	Slots      int32           `json:"slots"`
	Deposit    int64           `json:"deposit"`
	Quote      json.RawMessage `json:"quote,omitempty"`
}

func (c *TzKTClient) GetOperationInformation(ctx context.Context, hash string) ([]Operation, error) {
	path := fmt.Sprintf("/v1/operations/transactions/%s", hash)

	var results []Operation
	err := c.makeRequest(ctx, path, &results)

	if err != nil {
		return nil, fmt.Errorf("failed to make operation request: %w", err)
	}
	return results, nil
}
