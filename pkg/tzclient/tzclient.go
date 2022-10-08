package tzclient

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"

	"blockwatch.cc/tzgo/tezos"
	"blockwatch.cc/tzgo/micheline"
	"blockwatch.cc/tzgo/rpc"
)

// public types
type Wallet struct {
	Name	  string
	Address   string
	SecretKey string
	PublicKey string
}

type Contract struct {
	Name    string
	Address string
}

type Client struct {
	Path    string
	RPCURL  string
	Wallets map[string]Wallet
	Contracts map[string]Contract
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
		Path: path,
		Wallets: make(map[string]Wallet),
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
		wallet := Wallet {
			Name: hash.Name,
			Address: hash.Value,
		}
		client.Wallets[hash.Name] = wallet
	}

	content, err = ioutil.ReadFile(filepath.Join(path, "public_keys"))
    if err != nil {
        return Client{}, fmt.Errorf("failed to open tezos-client public keys: %w", err)
    }
    var public_keys []tezosClientPublicKey
    err = json.Unmarshal(content, &public_keys)
    if err != nil {
		return Client{}, fmt.Errorf("failed to decode tezos-client public keys: %w", err)
    }
	for _, key := range public_keys {
		if wallet, ok := client.Wallets[key.Name]; ok {
			wallet.PublicKey, err = key.Key()
			if err != nil {
				return Client{}, fmt.Errorf("error looking up key for %s: %w", key.Name, err)
			}
		}
	}

	content, err = ioutil.ReadFile(filepath.Join(path, "secret_keys"))
    if err != nil {
        return Client{}, fmt.Errorf("failed to open tezos-client secret keys: %w", err)
    }
    var secret_keys []tezosClientValue
    err = json.Unmarshal(content, &secret_keys)
    if err != nil {
		return Client{}, fmt.Errorf("failed to decode tezos-client secret kets: %w", err)
    }
	for _, key := range secret_keys {
		if wallet, ok := client.Wallets[key.Name]; ok {
			wallet.SecretKey = key.Value
		}
	}

	content, err = ioutil.ReadFile(filepath.Join(path, "contracts"))
    if err != nil {
        return Client{}, fmt.Errorf("failed to open tezos-client contracts: %w", err)
    }
    var contracts []tezosClientValue
    err = json.Unmarshal(content, &contracts)
    if err != nil {
		return Client{}, fmt.Errorf("failed to decode tezos-client secret kets: %w", err)
    }
	for _, contract_info := range contracts {
		contract := Contract{
			Name: contract_info.Name,
			Address: contract_info.Value,
		}
		client.Contracts[contract_info.Name] = contract
	}

	return client, nil
}

func LoadDefaultClient() (Client, error) {
	default_path := filepath.Join(os.Getenv("HOME"), ".tezos-client")
	return LoadClient(default_path)
}

func (c *Client) GetContractStorage(address string, ctx context.Context) (interface{}, error) {
	addr := tezos.MustParseAddress(address)
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

func (c *Client) GetBigMap(identifier int64, ctx context.Context) (interface{}, error) {
	rpcClient, err := rpc.NewClient(c.RPCURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create client: %w", err)
	}

	biginfo, err := rpcClient.GetActiveBigmapInfo(ctx, identifier)
	if err != nil {
		return nil, fmt.Errorf("failed to get big map info: %w", err)
	}

	// list all bigmap keys - we should use an indexer here, as this can be slow
	bigkeys, err := rpcClient.ListActiveBigmapKeys(ctx, identifier)
	if err != nil {
		return nil, fmt.Errorf("failed to get big map keys: %w", err)
	}

	// visit each value
	for _, key := range bigkeys {
		fmt.Printf("%T %v\n", key, key)
		bigval, _ := rpcClient.GetActiveBigmapValue(ctx, identifier, key)

		// unfold Micheline type into human readable form
		val := micheline.NewValue(micheline.NewType(biginfo.ValueType), bigval)
		m, _ := val.Map()
		buf, _ := json.MarshalIndent(m, "", "  ")
		fmt.Println(string(buf))
	}

	return nil, nil
}




