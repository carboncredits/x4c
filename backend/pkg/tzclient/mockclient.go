package tzclient

import (
	"context"
	"fmt"
	"reflect"

	"blockwatch.cc/tzgo/micheline"

	"quantify.earth/x4c/pkg/tzkt"
)

// This is a version of the client used for testing. Normally I'd put this in test
// code, but its needed in several different modules in the project, so I've pulled
// it in as common code.
type MockClient struct {
	ShouldError bool
	Storage     interface{}
	Items       map[int64][]tzkt.BigMapItem
}

func NewMockClient() MockClient {
	return MockClient{
		Items: make(map[int64][]tzkt.BigMapItem),
	}
}

func (c *MockClient) AddBigMap(identifier int64, items []tzkt.BigMapItem) {
	c.Items[identifier] = items
}

func (c MockClient) ContractByName(name string) (Contract, error) {
	return Contract{}, fmt.Errorf("contract not found")
}

func (c MockClient) GetIndexerWebURL() string {
	return "https://index.web"
}

func (c MockClient) GetContractStorage(target Contract, ctx context.Context, storage interface{}) error {
	if c.ShouldError {
		return fmt.Errorf("Test should fail")
	}
	if c.Storage != nil {
		t := reflect.TypeOf(storage)
		if (t == reflect.TypeOf(c.Storage)) && (t.Kind() == reflect.Ptr) {
			src := reflect.ValueOf(c.Storage).Elem()
			dst := reflect.ValueOf(storage).Elem()
			inner_type := reflect.TypeOf(src.Interface())
			for i := 0; i < src.NumField(); i++ {
				src_field := src.Field(i)
				dst_field := dst.Field(i)
				if inner_type.Field(i).IsExported() {
					dst_field.Set(src_field)
				}
			}
		}
	}
	return nil
}

func (c MockClient) GetBigMapContents(ctx context.Context, identifier int64) ([]tzkt.BigMapItem, error) {
	if c.ShouldError {
		return nil, fmt.Errorf("Test should fail")
	}
	if items, ok := c.Items[identifier]; ok {
		return items, nil
	} else {
		// The tzkt API returns empty list if you ask for an invalid ID
		// Though you could also argue we should return other garbage here, as that's also
		// a valid response, that's handled in other test cases
		return make([]tzkt.BigMapItem, 0), nil
	}
}

func (c MockClient) GetContractEvents(ctx context.Context, contractAddress string, tag string) ([]tzkt.Event, error) {
	if c.ShouldError {
		return nil, fmt.Errorf("Test should fail")
	}
	return nil, nil
}

func (c MockClient) GetOperationInformation(ctx context.Context, hash string) ([]tzkt.Operation, error) {
	if c.ShouldError {
		return nil, fmt.Errorf("Test should fail")
	}
	return nil, nil
}

func (c MockClient) CallContract(ctx context.Context, signedBy Wallet, target Contract, parameters micheline.Parameters) (string, error) {
	if c.ShouldError {
		return "", fmt.Errorf("Test should fail")
	}
	return "operationHash", nil
}

func (c MockClient) Originate(ctx context.Context, signedBy Wallet, code []byte, initial_storage micheline.Prim) (Contract, error) {
	if c.ShouldError {
		return Contract{}, fmt.Errorf("Test should fail")
	}
	return Contract{}, nil
}
