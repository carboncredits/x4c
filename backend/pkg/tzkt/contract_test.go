package tzkt

import (
	"context"
	"io"
	"net/http"
	"net/url"
	"strings"
	"testing"
)

type TestContractStorage struct {
	SomeAddress string `json:"address"`
	SomeBigMap  int64  `json:"ledger"`
}

func TestGetContractStorage(t *testing.T) {

	testcases := []struct {
		Payload    string
		StatusCode int

		ExpectError bool
	}{
		{
			Payload:     `{"code":400,"errors":{"address":"Invalid KT1-address."}}`,
			StatusCode:  http.StatusBadRequest,
			ExpectError: true,
		},
		{
			// Valid contract address that hasn't been originated
			Payload:     ``,
			StatusCode:  http.StatusNoContent,
			ExpectError: true,
		},
		{
			Payload:     "Gateway down",
			StatusCode:  http.StatusInternalServerError,
			ExpectError: true,
		},
		// we really need JSON-schema here :/
		// this is commented out as a reminder that this test should fail but doesn't
		// {
		// 	Payload: `
		// 		{
		// 			"This": "Is the wrong",
		// 			"Payload": 42
		// 		}
		// 	`,
		// 	StatusCode: http.StatusOK,
		// 	ExpectError: false,
		// },
		{
			Payload: `
				{
					"address": "tz1SkMkxb62QeArnqQa4aJZtXYkPpiqein9S",
					"ledger": 1234
				}
			`,
			StatusCode:  http.StatusOK,
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
		var storage TestContractStorage
		err := tzclient.GetContractStorage(ctx, "KT1MHx2nw8y2JyryGbuAvTYPNGwrfTp4PEYR", &storage)
		if testcase.ExpectError {
			if err == nil {
				t.Errorf("Testcase %d expected error, got none", index)
			}
		} else {
			if err != nil {
				t.Errorf("Testcase %d expected no error, got: %v", index, err)
			}
			if storage.SomeBigMap != 1234 {
				t.Errorf("Unexpected bigmap value: %v", storage)
			}
			if storage.SomeAddress != "tz1SkMkxb62QeArnqQa4aJZtXYkPpiqein9S" {
				t.Errorf("Unexpected address value: %v", storage)
			}
		}
	}
}
