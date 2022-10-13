package tzclient

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"

	"blockwatch.cc/tzgo/codec"
	"blockwatch.cc/tzgo/micheline"
	"blockwatch.cc/tzgo/rpc"
	"blockwatch.cc/tzgo/signer"
	"blockwatch.cc/tzgo/tezos"

	"quantify.earth/x4c/pkg/tzkt"
)

// public types

// TezosClient is a generic interface that lets us mock out the backend for testing
type TezosClient interface {
	GetContractStorage(target Contract, ctx context.Context, storage interface{}) error
	GetBigMapContents(ctx context.Context, identifier int64) ([]tzkt.BigMapItem, error)
	GetOperationInformation(ctx context.Context, hash string) ([]tzkt.Operation, error)
	CallContract(ctx context.Context, signedBy Wallet, target Contract, parameters micheline.Parameters) (string, error)
}

type Client struct {
	Path          string
	RPCURL        string
	IndexerRPCURL string
	IndexerWebURL string
	Wallets       map[string]Wallet
	Contracts     map[string]Contract
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

func LoadClient(path string) (Client, error) {
	client := Client{
		Path:      path,
		Wallets:   make(map[string]Wallet),
		Contracts: make(map[string]Contract),
	}

	content, err := ioutil.ReadFile(filepath.Join(path, "config"))
	if err != nil {
		return Client{}, fmt.Errorf("failed to open tezos-client config: %w", err)
	}
	var config tezosClientConfig
	err = json.Unmarshal(content, &config)
	if err != nil {
		return Client{}, fmt.Errorf("failed to decode tezos-client config: %w", err)
	}
	client.RPCURL = config.Endpoint

	if strings.Contains(client.RPCURL, "kathmandunet") {
		client.IndexerRPCURL = "https://api.kathmandunet.tzkt.io/"
		client.IndexerWebURL = "https://kathmandunet.tzkt.io/"
	} else if strings.Contains(client.RPCURL, "ghostnet") {
		client.IndexerRPCURL = "https://api.ghostnet.tzkt.io/"
		client.IndexerWebURL = "https://ghostnet.tzkt.io/"
	} else {
		client.IndexerRPCURL = "https://api.mainnet.tzkt.io/"
		client.IndexerWebURL = "https://mainnet.tzkt.io/"
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
		return Client{}, fmt.Errorf("failed to open tezos-client contracts: %w", err)
	}
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

	return client, nil
}

func LoadDefaultClient() (Client, error) {
	default_path := filepath.Join(os.Getenv("HOME"), ".tezos-client")
	return LoadClient(default_path)
}

func (c *Client) DirectGetContractStorage(address string, ctx context.Context) (interface{}, error) {
	addr, err := tezos.ParseAddress(address)
	if err != nil {
		return nil, fmt.Errorf("failed to parse address: %w", err)
	}
	if addr.Type != tezos.AddressTypeContract {
		return nil, fmt.Errorf("invalid contract address")
	}

	rpcClient, err := rpc.NewClient(c.RPCURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create client: %w", err)
	}

	script, err := rpcClient.GetContractScript(ctx, addr)
	if err != nil {
		return nil, fmt.Errorf("failed to get storage: %w", err)
	}

	// unfold Micheline storage into human-readable form
	val := micheline.NewValue(script.StorageType(), script.Storage)

	m, err := val.Map()
	if err != nil {
		return nil, fmt.Errorf("failed to decode storage: %w", err)
	}
	return m, nil
}

func (c Client) CallContract(ctx context.Context, signedBy Wallet, target Contract, parameters micheline.Parameters) (string, error) {

	rpcClient, err := rpc.NewClient(c.RPCURL, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create client: %w", err)
	}
	rpcClient.Init(ctx)
	rpcClient.Listen()

	if signedBy.Key == nil {
		return "", fmt.Errorf("Signer wallet %s has no private key", signedBy.Name)
	}

	rpcClient.Signer = signer.NewFromKey(*signedBy.Key)

	op := codec.NewOp().WithSource(signedBy.Address)
	op.WithCall(target.Address, parameters)

	// send operation with default options
	result, err := modifiedSend(rpcClient, ctx, op, nil)
	if err != nil {
		return "", err
	}

	// return just the operation hash
	return result.Hash().String(), nil
}

// modifiedSend is a version of the tzgo rpcclient Send function, but we don't wait for a confirmation of the
// the block. In an ideal world I'd be able to use a custom block observer to do that, but I can't quite see
// how, and just to get a proof-of-concept working, I've done a bit of a copy and paste and then delete.
func modifiedSend(c *rpc.Client, ctx context.Context, op *codec.Op, opts *rpc.CallOptions) (*rpc.Result, error) {
	if opts == nil {
		opts = &rpc.DefaultOptions
	}

	signer := c.Signer
	if opts.Signer != nil {
		signer = opts.Signer
	}

	// identify the sender address for signing the message
	addr := opts.Sender
	if !addr.IsValid() {
		addrs, err := signer.ListAddresses(ctx)
		if err != nil {
			return nil, err
		}
		addr = addrs[0]
	}

	key, err := signer.GetKey(ctx, addr)
	if err != nil {
		return nil, err
	}

	// set source on all ops
	op.WithSource(key.Address())

	// auto-complete op with branch/ttl, source counter, reveal
	err = c.Complete(ctx, op, key)
	if err != nil {
		return nil, err
	}

	// simulate to check tx validity and estimate cost
	sim, err := c.Simulate(ctx, op, opts)
	if err != nil {
		return nil, err
	}

	// fail with Tezos error when simulation failed
	if !sim.IsSuccess() {
		return nil, sim.Error()
	}

	// apply simulated cost as limits to tx list
	if !opts.IgnoreLimits {
		op.WithLimits(sim.MinLimits(), rpc.GasSafetyMargin)
	}

	// check minFee calc against maxFee if set
	if opts.MaxFee > 0 {
		if l := op.Limits(); l.Fee > opts.MaxFee {
			return nil, fmt.Errorf("estimated cost %d > max %d", l.Fee, opts.MaxFee)
		}
	}

	// sign digest
	sig, err := signer.SignOperation(ctx, addr, op)
	if err != nil {
		return nil, err
	}
	op.WithSignature(sig)

	// broadcast
	hash, err := c.Broadcast(ctx, op)
	if err != nil {
		return nil, err
	}

	res := rpc.NewResult(hash).WithTTL(op.TTL).WithConfirmations(opts.Confirmations)

	// This is where in the tzgo code they wait for confirmations, we do not

	return res, nil
}

// These just call through to the indexer
func (c Client) GetContractStorage(target Contract, ctx context.Context, storage interface{}) error {
	indexer, err := tzkt.NewClient(c.IndexerRPCURL)
	if err != nil {
		return fmt.Errorf("Failed to make indexer: %w", err)
	}
	err = indexer.GetContractStorage(ctx, target.Address.String(), storage)
	if err != nil {
		return fmt.Errorf("Failed to make indexer: %w", err)
	}

	return nil
}

func (c Client) GetBigMapContents(ctx context.Context, identifier int64) ([]tzkt.BigMapItem, error) {
	indexer, err := tzkt.NewClient(c.IndexerRPCURL)
	if err != nil {
		return nil, fmt.Errorf("Failed to make indexer: %w", err)
	}
	return indexer.GetBigMapContents(ctx, identifier)
}

func (c Client) GetOperationInformation(ctx context.Context, hash string) ([]tzkt.Operation, error) {
	indexer, err := tzkt.NewClient(c.IndexerRPCURL)
	if err != nil {
		return nil, fmt.Errorf("Failed to make indexer: %w", err)
	}
	return indexer.GetOperationInformation(ctx, hash)
}

func (c Client) GetContractEvents(ctx context.Context, contractAddress string, tag string) ([]tzkt.Event, error) {
	indexer, err := tzkt.NewClient(c.IndexerRPCURL)
	if err != nil {
		return nil, fmt.Errorf("Failed to make indexer: %w", err)
	}
	return indexer.GetContractEvents(ctx, contractAddress, tag)
}
