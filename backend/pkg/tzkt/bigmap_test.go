package tzkt

import (
	"context"
	"io"
	"net/http"
	"net/url"
	"strings"
	"testing"
)

type HTTPClientMock struct {
	// DoFunc will be executed whenever Do function is executed
	// so we'll be able to create a custom response
	DoFunc func(*http.Request) (*http.Response, error)
}

func (H HTTPClientMock) Do(r *http.Request) (*http.Response, error) {
	return H.DoFunc(r)
}

func TestGetBigMap(t *testing.T) {

	testcases := []struct {
		Payload    string
		StatusCode int

		Count       int
		ExpectError bool
	}{
		{
			// This case covers both empty big map and invalid ID
			Payload:     "[]",
			StatusCode:  http.StatusOK,
			Count:       0,
			ExpectError: false,
		},
		{
			Payload:     "Gateway down",
			StatusCode:  http.StatusInternalServerError,
			Count:       0,
			ExpectError: true,
		},
		{
			Payload: `[
				{
					"This": "Is the wrong",
					"Payload": 42
				}
			]`,
			StatusCode:  http.StatusOK,
			Count:       0,
			ExpectError: true,
		},
		{
			// golang by defaults treats contents as optional, so if we're
			// not careful this is considered valid
			Payload: `[
				{
				}
			]`,
			StatusCode:  http.StatusOK,
			Count:       0,
			ExpectError: true,
		},
		{
			Payload: `[
				{
					"id": 131066,
					"active": false,
					"hash": "exprumPYk1WQo92cnqQ67ZDn26HMpSSHxXcY8ALtvcHXMQFMjhTrtQ",
					"key": {
						"kyc": "05010000000473656c66",
						"token": {
							"token_id": "123",
							"token_address": "KT1MHx2nw8y2JyryGbuAvTYPNGwrfTp4PEYR"
						}
					},
					"value": "500",
					"firstLevel": 371199,
					"lastLevel": 371202,
					"updates": 3
				}
			]`,
			StatusCode:  http.StatusOK,
			Count:       1,
			ExpectError: false,
		},
	}

	base_url, _ := url.Parse("http://test.com")
	mockClient := &HTTPClientMock{}
	tzclient := TzKTClient{
		client:  mockClient,
		BaseURL: base_url,
	}

	for index, testcase := range testcases {
		mockClient.DoFunc = func(r *http.Request) (*http.Response, error) {
			return &http.Response{
				Body:       io.NopCloser(strings.NewReader(testcase.Payload)),
				StatusCode: testcase.StatusCode,
			}, nil
		}

		ctx := context.Background()
		resp, err := tzclient.GetBigMapContents(ctx, 1234)
		if testcase.ExpectError {
			if err == nil {
				t.Errorf("Testcase %d expected error, got none", index)
			}
		} else {
			if err != nil {
				t.Errorf("Testcase %d expected no error, got: %v", index, err)
			}
			if len(resp) != testcase.Count {
				t.Errorf("Testcase %d expected %d items, got %d: %v", index, testcase.Count, len(resp), resp)
			}
		}
	}
}
