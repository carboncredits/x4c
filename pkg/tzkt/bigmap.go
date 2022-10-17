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

	// Until we get some json schema action in here, and given there is no "required" validation in golang's
	// json library, so a quick sanitation check
	for index, item := range results {
		if item.Identifier == 0 {
			return nil, fmt.Errorf("item %d had invalid identifier %d", index, item.Identifier)
		}
		if item.Hash == "" {
			return nil, fmt.Errorf("item %d had empty hash", index)
		}
	}

	return results, nil
}
