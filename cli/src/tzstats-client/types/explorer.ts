export interface IndexerStatus {
  mode: "sync",
  status: "connecting" | "syncing" | "synced" | "failed",
  blocks: number;
  indexed: number;
  progress: number;
}

type ContractFeature = "ccount_factory" | "contract_factory" | "set_delegate" | "lambda" | "transfer_tokens" | "chain_id" | "ticket" | "sapling" | "view" | "global_constant" | "timelock" 

export interface Contract {
  account_id: number,
  address: string,
  creator: string,
  baker: string,
  storage_size: number,
  storage_paid: number,
  first_seen: number,
  last_seen: number,
  first_seen_time: Date,
  last_seen_time: Date,
  n_calls_success: number,
  n_calls_failed: number,
  bigmaps: {
    accounts: number
  },
  iface_hash: string,
  code_hash: string,
  storage_hash: string,
  call_stats: {
    addLiquidity: number,
    approve: number,
    default: number,
    removeLiquidity: number,
    setBaker: number,
    setManager: number,
    tokenToToken: number,
    tokenToXtz: number,
    updateTokenPool: number,
    updateTokenPoolInternal: number,
    xtzToToken: number
  },
  features: ContractFeature[],
  interfaces: string[]
}

export interface ContractStorage {
    value: object
    prim?: object
}

export interface ContractCalls {
    entrypoint: "default" | "entrypoint_00"
    value: object
    prim?: object
    method: string
    argument: object
}

export interface Account {
  row_id: number
  address: string
  address_type: string
  pubkey: string
  counter: number
  first_in: number
  first_out: number
  last_in: number
  last_out: number
  first_seen: number
  last_seen: number
  first_in_time: Date
  first_out_time: Date
  last_in_time: Date
  last_out_time: Date
  first_seen_time: Date
  last_seen_time: Date
  total_received: number
  total_sent: number
  total_burned: number
  total_fees_paid: number
  spendable_balance: number
  is_funded: boolean
  is_activated: boolean
  is_delegated: boolean
  is_revealed: boolean
  is_baker: boolean
  is_contract: boolean
  n_ops: number
  n_ops_failed: number
  n_tx: number
  n_delegation: number
  n_origination: number
  n_constants: number
  token_gen_min: number
  token_gen_max: number
  frozen_bond: number
  lost_bond: number
  metadata: object
  creator?: string // Creator-only
  baker?: string  // Delegator-only
  delegated_since?: string // Delegator-only
  delegated_since_time?: Date // Delegator-only
}

export interface Operation {
  id: string
  hash: string
  block: string
  time: Date
  status: string
  sender: string
  receiver: string
  parameters: { entrypoint: string, value: any[] }
}