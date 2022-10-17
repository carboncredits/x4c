package tzkt

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httputil"
	"net/url"
)

const (
	mediaType = "application/json"
)

// Use an interface here to let us mock this in testing
type HTTPClient interface {
	Do(*http.Request) (*http.Response, error)
}

type TzKTClient struct {
	client  HTTPClient
	BaseURL *url.URL
}

func NewClient(address string) (TzKTClient, error) {
	base_url, err := url.Parse(address)
	if err != nil {
		return TzKTClient{}, fmt.Errorf("failed to parse base url: %w", err)
	}
	if base_url == nil {
		return TzKTClient{}, fmt.Errorf("Expected non nil url")
	}

	return TzKTClient{
		client:  &http.Client{},
		BaseURL: base_url,
	}, nil
}

func (c *TzKTClient) makeRequest(ctx context.Context, path string, result interface{}) error {
	rel, err := url.Parse(path)
	if err != nil {
		return fmt.Errorf("faild to parse %s: %w", path, err)
	}
	target_url := c.BaseURL.ResolveReference(rel)

	req, err := http.NewRequest("GET", target_url.String(), nil)
	if err != nil {
		return fmt.Errorf("could not build request: %w", err)
	}
	req = req.WithContext(ctx)

	req.Header.Add("Content-Type", mediaType)
	req.Header.Add("Accept", mediaType)

	resp, err := c.client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to make request: %w", err)
	}
	defer func() {
		resp.Body.Close()
	}()

	if resp.StatusCode != http.StatusOK {
		// ignore the error if we don't get a response, the status code
		// response is what the upper layers actually care about
		respDump, _ := httputil.DumpResponse(resp, true)
		return fmt.Errorf("Server responded with %d: %s", resp.StatusCode, respDump)
	}

	if result != nil {
		decoder := json.NewDecoder(resp.Body)
		decoder.DisallowUnknownFields()
		err = decoder.Decode(result)
		if err != nil {
			return fmt.Errorf("failed to decode response: %w", err)
		}
	}

	return nil
}
