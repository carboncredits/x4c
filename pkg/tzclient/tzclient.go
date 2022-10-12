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
	"blockwatch.cc/tzgo/contract"
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
	CallContract(ctx context.Context, signedBy Wallet, target Contract, parameters micheline.Parameters) error
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


func (c Client) CallContract(ctx context.Context, signedBy Wallet, target Contract, parameters micheline.Parameters) error {

	rpcClient, err := rpc.NewClient(c.RPCURL, nil)
	if err != nil {
		return fmt.Errorf("failed to create client: %w", err)
	}
	rpcClient.Init(ctx)
	rpcClient.Listen()

	if signedBy.Key == nil {
		return fmt.Errorf("Signer wallet %s has no private key", signedBy.Name)
	}

    rpcClient.Signer = signer.NewFromKey(*signedBy.Key)

    op := codec.NewOp().WithSource(signedBy.Address)
	op.WithCall(target.Address, parameters)

    // send operation with default options
    result, err := modifiedSend(rpcClient, ctx, op, nil)
    if err != nil {
        return err
    }

	fmt.Printf("%v\n", result.Hash().String())
	return nil
}


func (c Client) CallContractLocked(ctx context.Context, signedBy Wallet, target Contract, parameters micheline.Parameters) error {

	if signedBy.Key == nil {
		return fmt.Errorf("Signer wallet %s has no private key", signedBy.Name)
	}

	opts := rpc.DefaultOptions
	opts.Signer = signer.NewFromKey(*signedBy.Key)
	opts.Confirmations = 0
	opts.TTL = 0

	rpcClient, err := rpc.NewClient(c.RPCURL, nil)
	if err != nil {
		return fmt.Errorf("failed to create client: %w", err)
	}
	rpcClient.Init(ctx)
	rpcClient.Listen()

	tezos_contract := contract.NewContract(target.Address, rpcClient)
	if err := tezos_contract.Resolve(ctx); err != nil {
		return fmt.Errorf("failed to resolve contract: %w", err)
	}

	args := contract.TxArgs{
		Source:      signedBy.Address,
		Destination: target.Address,
		Amount:      0.0,
		Params:      parameters,
	}

	receipt, err := tezos_contract.Call(ctx, &args, &opts)
	if err != nil {
		return fmt.Errorf("failed to call contract: %w", err)
	}
	fmt.Printf("receipt: %v", receipt)
	return nil
}


// Send is a convenience wrapper for sending operations. It auto-completes gas and storage limit,
// ensures minimum fees are set, protects against fee overpayment, signs and broadcasts the final
// operation and waits for a defined number of confirmations.
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

	// // log info about tx costs
	// logDebug(func() {
	// 	costs := sim.Costs()
	// 	for i, v := range op.Contents {
	// 		verb := "used"
	// 		if opts.IgnoreLimits {
	// 			verb = "forced"
	// 		}
	// 		limits := v.Limits()
	// 		log.Debugf("OP#%03d: %s gas_used(sim)=%d storage_used(sim)=%d storage_burn(sim)=%d alloc_burn(sim)=%d fee(%s)=%d gas_limit(%s)=%d storage_limit(%s)=%d ",
	// 			i, v.Kind(), costs[i].GasUsed, costs[i].StorageUsed, costs[i].StorageBurn, costs[i].AllocationBurn,
	// 			verb, limits.Fee, verb, limits.GasLimit, verb, limits.StorageLimit,
	// 		)
	// 	}
	// })

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
	fmt.Printf("Hash: %v\n", hash)

	// wait for confirmations
	res := rpc.NewResult(hash).WithTTL(op.TTL).WithConfirmations(opts.Confirmations)
	fmt.Printf("a %v\n", res)

	// use custom observer when provided
	// mon := c.BlockObserver
	// if opts.Observer != nil {
	// 	mon = opts.Observer
	// }

	// fmt.Printf("%v\n", mon)
	// // wait for confirmations
	// res.Listen(mon)
	// fmt.Println("b")
	// res.WaitContext(ctx)
	// fmt.Println("c")
	// if err := res.Err(); err != nil {
	// 	return nil, err
	// }

	fmt.Println("d")
	// return receipt
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
