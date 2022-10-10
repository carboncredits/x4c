package tzkt

import (
	"context"
	"fmt"
)

func (c *TzKTClient) GetContractStorage(ctx context.Context, contractAddress string, storage interface{}) error {
	path := fmt.Sprintf("/v1/contracts/%s/storage", contractAddress)
	err := c.makeRequest(ctx, path, storage)
	if err != nil {
		return fmt.Errorf("failed to make request: %w", err)
	}
	return nil
}
