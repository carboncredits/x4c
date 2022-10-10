package tzkt

import (
	"context"
	"encoding/json"
	"fmt"
)

type BigMapItem struct {
	Identifier int64           `json:"id"`
	Active     bool            `json:"active"`
	Hash       string          `json:"hash"`
	Key        json.RawMessage `json:"key"`
	Value      json.RawMessage `json:"value"`
	FirstLevel int64           `json:"firstLevel"`
	LastLevel  int64           `json:"lastLevel"`
	Updates    int64           `json:"updates"`
}

func (c *TzKTClient) GetBigMapContents(ctx context.Context, identifier int64) ([]BigMapItem, error) {
	path := fmt.Sprintf("/v1/bigmaps/%d/keys", identifier)

	var results []BigMapItem
	err := c.makeRequest(ctx, path, &results)

	if err != nil {
		return nil, fmt.Errorf("failed to make request: %w", err)
	}
	return results, nil
}
