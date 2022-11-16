package tzclient

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"

	"blockwatch.cc/tzgo/codec"
	"blockwatch.cc/tzgo/contract"
	"blockwatch.cc/tzgo/micheline"
	"blockwatch.cc/tzgo/rpc"
	"blockwatch.cc/tzgo/signer"
	"blockwatch.cc/tzgo/signer/remote"
	"github.com/echa/log"

	"quantify.earth/x4c/pkg/tzkt"
)

const maxRetries = 5

// public types

// TezosClient is a generic interface that lets us mock out the backend for testing
type TezosClient interface {
	GetContractStorage(target Contract, ctx context.Context, storage interface{}) error
	GetBigMapContents(ctx context.Context, identifier int64) ([]tzkt.BigMapItem, error)
	GetOperationInformation(ctx context.Context, hash string) ([]tzkt.Operation, error)
	GetContractEvents(ctx context.Context, contractAddress string, tag string) ([]tzkt.Event, error)
	CallContract(ctx context.Context, signedBy Wallet, target Contract, parameters micheline.Parameters) (string, error)
	Originate(ctx context.Context, signedBy Wallet, code []byte, initial_storage micheline.Prim) (Contract, error)

	// Mostly to stop people accessing struct fields directly so we can mock out
	// the client for testing.
	ContractByName(name string) (Contract, error)
	GetIndexerWebURL() string
}

type Client struct {
	RPCURL        string
	IndexerRPCURL string
	SignatoryURL  string
	Wallets       map[string]Wallet
	Contracts     map[string]Contract

	path          string
	indexerWebURL string
}

// internal types

type tezosClientConfig struct {
	Endpoint string `json:"endpoint"`
}

// used by both secret_keys and public_key_hashs(sic)
type tezosClientValue struct {
	Name  string `json:"name"`
	Value string `json:"value"`
}

type tezosClientPublicKey struct {
	Name  string      `json:"name"`
	Value interface{} `json:"value"` // this can be a string or a struct :/
}

func (t tezosClientPublicKey) Key() (string, error) {
	switch v := t.Value.(type) {
	case string:
		return v, nil
	case map[string]interface{}:
		possible_key := v["key"]
		switch p := possible_key.(type) {
		case string:
			return p, nil
		default:
			return "", fmt.Errorf("Unexpected inner type %T found", v)
		}
	default:
		return "", fmt.Errorf("Unexpected type %T found", v)
	}
}

// public code
func NewClient() (Client, error) {
	client := Client{
		path:      "",
		Wallets:   make(map[string]Wallet),
		Contracts: make(map[string]Contract),
	}

	// first check env for hosts
	client.RPCURL = os.Getenv("TEZOS_RPC_HOST")
	if client.RPCURL == "" {
		return Client{}, fmt.Errorf("TEZOS_RPC_HOST is not configured")
	}

	client.IndexerRPCURL = os.Getenv("TEZOS_INDEX_HOST")
	if client.RPCURL == "" {
		return Client{}, fmt.Errorf("TEZOS_INDEX_HOST is not configured")
	}

	// These two are optional
	client.indexerWebURL = os.Getenv("TEZOS_INDEX_WEB")
	client.SignatoryURL = os.Getenv("SIGNATORY_HOST")

	return client, nil
}

func LoadClient(path string) (Client, error) {
	client := Client{
		path:      path,
		Wallets:   make(map[string]Wallet),
		Contracts: make(map[string]Contract),
	}

	// first check env for hosts
	client.RPCURL = os.Getenv("TEZOS_RPC_HOST")
	client.IndexerRPCURL = os.Getenv("TEZOS_INDEX_HOST")
	client.indexerWebURL = os.Getenv("TEZOS_INDEX_WEB")
	client.SignatoryURL = os.Getenv("SIGNATORY_HOST")

	content, err := ioutil.ReadFile(filepath.Join(path, "config"))
	if err != nil {
		return Client{}, fmt.Errorf("failed to open tezos-client config: %w", err)
	}
	var config tezosClientConfig
	err = json.Unmarshal(content, &config)
	if err != nil {
		return Client{}, fmt.Errorf("failed to decode tezos-client config: %w", err)
	}

	// If the env didn't specify things, try to infer where things are from the config file
	if client.RPCURL == "" {
		if config.Endpoint == "" {
			return Client{}, fmt.Errorf("no rpc endpoint found in tezos-client config - try running 'tezos-client config update'")
		}
		client.RPCURL = config.Endpoint

		if strings.Contains(client.RPCURL, "kathmandunet") {
			client.IndexerRPCURL = "https://api.kathmandunet.tzkt.io/"
			client.indexerWebURL = "https://kathmandunet.tzkt.io/"
		} else if strings.Contains(client.RPCURL, "ghostnet") {
			client.IndexerRPCURL = "https://api.ghostnet.tzkt.io/"
			client.indexerWebURL = "https://ghostnet.tzkt.io/"
		} else {
			client.IndexerRPCURL = "https://api.mainnet.tzkt.io/"
			client.indexerWebURL = "https://mainnet.tzkt.io/"
		}
	}

	// tezos-client has redundent information stored - both the address/hash and public key
	// can be derived from the secret key, so we just load secret keys first, and then any other keys
	// we just load the address for (and not the public key, as that's not currently of use).

	content, err = ioutil.ReadFile(filepath.Join(path, "secret_keys"))
	if err != nil {
		return Client{}, fmt.Errorf("failed to open tezos-client secret keys: %w", err)
	}
	var secret_keys []tezosClientValue
	err = json.Unmarshal(content, &secret_keys)
	if err != nil {
		return Client{}, fmt.Errorf("failed to decode tezos-client secret keys: %w", err)
	}
	for _, key := range secret_keys {
		// In the tezos client the keys have a prefix to indicate how they're stored. For now
		// just deal with the unencrypted default
		if !strings.HasPrefix(key.Value, "unencrypted:") {
			return Client{}, fmt.Errorf("Key for %s has unexpected secret key format.", key.Name)
		}
		value := strings.TrimPrefix(key.Value, "unencrypted:")

		wallet, err := NewWalletWithPrivateKey(key.Name, value)
		if err != nil {
			return Client{}, fmt.Errorf("failed to parse key for %s: %w", key.Name, err)
		}
		client.Wallets[key.Name] = wallet
	}

	content, err = ioutil.ReadFile(filepath.Join(path, "public_key_hashs"))
	if err != nil {
		return Client{}, fmt.Errorf("failed to open tezos-client hashes: %w", err)
	}
	var hashes []tezosClientValue
	err = json.Unmarshal(content, &hashes)
	if err != nil {
		return Client{}, fmt.Errorf("failed to decode tezos-client hashes: %w", err)
	}
	for _, hash := range hashes {
		if _, ok := client.Wallets[hash.Name]; ok {
			continue
		}
		wallet, err := NewWalletWithAddress(hash.Name, hash.Value)
		if err != nil {
			return Client{}, fmt.Errorf("failed to parse hash for %s: %w", hash.Name, err)
		}
		client.Wallets[hash.Name] = wallet
	}

	// Contracts are similar format, but treated distinctly

	content, err = ioutil.ReadFile(filepath.Join(path, "contracts"))
	if err != nil {
		if !errors.Is(err, os.ErrNotExist) {
			return Client{}, fmt.Errorf("failed to open tezos-client contracts: %w", err)
		}
	} else {
		var contracts []tezosClientValue
		err = json.Unmarshal(content, &contracts)
		if err != nil {
			return Client{}, fmt.Errorf("failed to decode tezos-client contracts: %w", err)
		}
		for _, contract_info := range contracts {
			contract, err := NewContractWithAddress(contract_info.Name, contract_info.Value)
			if err != nil {
				return Client{}, fmt.Errorf("failed to parse contract %s: %w", contract_info.Name, err)
			}
			client.Contracts[contract_info.Name] = contract
		}
	}

	return client, nil
}

func LoadDefaultClient() (Client, error) {
	default_path := filepath.Join(os.Getenv("HOME"), ".tezos-client")
	return LoadClient(default_path)
}

func (c *Client) FindNameForAddress(address string) string {
	for name, info := range c.Wallets {
		if info.Address.String() == address {
			return name
		}
	}
	for name, info := range c.Contracts {
		if info.Address.String() == address {
			return name
		}
	}
	return address
}

func (c Client) ContractByName(name string) (Contract, error) {
	if contract, ok := c.Contracts[name]; ok {
		return contract, nil
	}
	for _, contract := range c.Contracts {
		if (contract.Name == name) || (contract.Address.String() == name) {
			return contract, nil
		}
	}
	return Contract{}, fmt.Errorf("contract not found")
}

func (c Client) GetIndexerWebURL() string {
	return c.indexerWebURL
}

func (c *Client) SaveContract(contract Contract) error {

	if c.path == "" {
		return fmt.Errorf("client has not storage path set")
	}

	if _, ok := c.Contracts[contract.Name]; ok {
		return fmt.Errorf("contract with name %s alread exists", contract.Name)
	}

	c.Contracts[contract.Name] = contract

	new_file_contents := make([]tezosClientValue, 0, len(c.Contracts))
	for _, info := range c.Contracts {
		new_file_value := tezosClientValue{
			Name:  info.Name,
			Value: info.Address.String(),
		}
		new_file_contents = append(new_file_contents, new_file_value)
	}

	data, err := json.MarshalIndent(new_file_contents, "", "    ")
	if err != nil {
		return fmt.Errorf("failed to marshall new contract file: %w", err)
	}

	err = ioutil.WriteFile(filepath.Join(c.path, "contracts"), data, 0644)
	if err != nil {
		return fmt.Errorf("failed to write new contract file: %w", err)
	}

	return nil
}

func (c Client) CallContract(ctx context.Context, signedBy Wallet, target Contract, parameters micheline.Parameters) (string, error) {

	rpcClient, err := rpc.NewClient(c.RPCURL, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create client: %w", err)
	}
	rpcClient.Init(ctx)
	rpcClient.Listen()

	if signedBy.Key == nil {
		// It's not a given that any hashes without keys are stored in signatory in
		// general, but in the 4C app context I think we can assert this is, if not
		// true. something we're happy to see errors for if we mess our tezos-client
		// stores for :)
		if c.SignatoryURL == "" {
			return "", fmt.Errorf("remote signer not configured for %v", signedBy.Name)
		}
		remoteSigner, err := remote.New(c.SignatoryURL, nil)
		if err != nil {
			return "", fmt.Errorf("failed to make remote signer for %v: %w", signedBy.Name, err)
		}
		if signedBy.Address.String() == "" {
			return "", fmt.Errorf("signer is missing address!")
		}
		rpcClient.Signer = remoteSigner.WithAddress(signedBy.Address)
	} else {
		rpcClient.Signer = signer.NewFromKey(*signedBy.Key)
	}

	op := codec.NewOp().WithSource(signedBy.Address)
	op.WithCall(target.Address, parameters)

	// send operation with default options
	var result *rpc.Receipt
	for tries := 0; true; tries += 1 {
		result, err = rpcClient.Send(ctx, op, nil)
		if err != nil {
			var urlError *url.Error
			if errors.As(err, &urlError) && (tries < maxRetries) {
				time.Sleep(500 * time.Millisecond)
				continue
			}
			return "", err
		}
		break
	}

	// return just the operation hash
	if (result == nil) || (result.Op == nil) {
		return "", fmt.Errorf("malformed result: %v", result)
	}
	return result.Op.Hash.String(), nil
}

// These just call through to the indexer
func (c Client) GetContractStorage(target Contract, ctx context.Context, storage interface{}) error {
	indexer, err := tzkt.NewClient(c.IndexerRPCURL)
	if err != nil {
		return fmt.Errorf("failed to make indexer: %w", err)
	}
	err = indexer.GetContractStorage(ctx, target.Address.String(), storage)
	if err != nil {
		return fmt.Errorf("failed to fetch storage: %w", err)
	}

	return nil
}

func (c Client) GetBigMapContents(ctx context.Context, identifier int64) ([]tzkt.BigMapItem, error) {
	indexer, err := tzkt.NewClient(c.IndexerRPCURL)
	if err != nil {
		return nil, fmt.Errorf("failed to make indexer: %w", err)
	}
	return indexer.GetBigMapContents(ctx, identifier)
}

func (c Client) GetOperationInformation(ctx context.Context, hash string) ([]tzkt.Operation, error) {
	indexer, err := tzkt.NewClient(c.IndexerRPCURL)
	if err != nil {
		return nil, fmt.Errorf("failed to make indexer: %w", err)
	}
	return indexer.GetOperationInformation(ctx, hash)
}

func (c Client) GetContractEvents(ctx context.Context, contractAddress string, tag string) ([]tzkt.Event, error) {
	indexer, err := tzkt.NewClient(c.IndexerRPCURL)
	if err != nil {
		return nil, fmt.Errorf("failed to make indexer: %w", err)
	}
	return indexer.GetContractEvents(ctx, contractAddress, tag)
}

func (c Client) Originate(ctx context.Context, signedBy Wallet, codedata []byte, initial_storage micheline.Prim) (Contract, error) {

	rpcClient, err := rpc.NewClient(c.RPCURL, nil)
	if err != nil {
		return Contract{}, fmt.Errorf("failed to create client: %w", err)
	}
	rpc.UseLogger(log.Log)
	contract.UseLogger(log.Log)

	if signedBy.Key == nil {
		return Contract{}, fmt.Errorf("signer wallet %s has no private key", signedBy.Name)
	}
	rpcClient.Signer = signer.NewFromKey(*signedBy.Key)

	rpcClient.Init(ctx)
	rpcClient.Listen()

	contract := contract.NewEmptyContract(rpcClient)
	code := micheline.Code{}
	err = code.UnmarshalJSON(codedata)
	if err != nil {
		return Contract{}, fmt.Errorf("failed to decode contract: %v", err)
	}
	script := micheline.Script{
		Code:    code,
		Storage: initial_storage,
	}
	contract.WithScript(&script)

	var receipt *rpc.Receipt
	for tries := 0; true; tries += 1 {
		receipt, err = contract.Deploy(ctx, nil)
		if err != nil {
			var urlError *url.Error
			if errors.As(err, &urlError) && (tries < maxRetries) {
				time.Sleep(500 * time.Millisecond)
				continue
			}
			return Contract{}, fmt.Errorf("failed to deploy: %v", err)
		}
		break
	}

	contract_address, err := NewContractWithAddress("new", contract.Address().String())
	if err != nil {
		return Contract{}, fmt.Errorf("Contract address %s of operation %s is invalid: %v",
			contract.Address(), receipt.Op.Hash.String(), err)
	}

	return contract_address, nil
}
