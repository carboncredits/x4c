// The main contract that controls the carbon credits project 

// TODO: Ratings (quantitative and qualitative). RIGHT.
//       ALL THIS MANAGED BY THE ADMIN PERSON
// TODO: Admin can change the ratings of a project?
// TODO: What happens if a project should be pulled? Or "deleted"?
// TODO: Should have a "fail" rating that translates into the price.
//       Qual: 0 1(C) 2(B) 3(A), etc.

#include "aux/deploy-x4c-project.mligo"

(* =============================================================================
 * Storage
 * ============================================================================= *)

type project_owner = address
type project_address = address 
type token = { token_address : address ; token_id : nat ; }

type create = { token_id : nat ; token_info : (string, bytes) map ; }
type mint   = { owner : address ; token_id : nat ; qty : nat ; }
type retire = { project_address : address ; token_id : nat ; qty : nat ; }

type create_project = create list * contract_metadata
type mint_tokens    = mint list
type retire_tokens = retire list
type retired_token = [@layout:comb]{
    token_owner : address ; 
    token : token ; 
    qty : nat ;
    time_retired : timestamp ;
}
type retired_tokens = retired_token list 

type approve_token = {
    token : token ; 
    allowance : nat ; // the number of tokens the project owner can mint
}
type approve_tokens = approve_token list

type proxy_update_ledger = 
| Projects of { project_owner : project_owner ; project_address_opt : project_address option ; }
| ProjectsUnit of { project_address : project_address ; exists_opt : unit option ; }
| MintingPermissions of { token : token ; qty_mintable_opt : nat option ; }

type storage = {
    // the oracle that approves projects and gives minting permissions (to be upgraded later)
    admin : address ;
    // keeps track of created projects
    projects : (project_owner, project_address) big_map ;
    projects_unit : (project_address, unit) big_map ; // for querying if a token contract is in this family
    // keeps track of the number of outstanding "mintable" tokens
    minting_permissions : (token, nat) big_map ; 
    retired_tokens : (address, retired_tokens) big_map ; // a record of buried carbon
    // for upgradeability
    directory : address ;
    is_active : bool ;
    previous_storage_contract : address option ; // if None, this is the first storage contract
    next_storage_contract : address option ; // if None, this is the active storage contract
}

(* =============================================================================
 * Entrypoint Type Definition
 * ============================================================================= *)

type entrypoint = 
| CreateProject of create_project 
| MintTokens of mint_tokens
| RetireTokens of retire_tokens 
| ApproveTokens of approve_tokens 
// for contract upgradeability
| Activate of bool
| ProxyUpdateLedger of proxy_update_ledger

type result = (operation list) * storage

(* =============================================================================
 * Error codes
 * ============================================================================= *)

let error_PROJECT_NOT_FOUND = 0n
let error_PERMISSIONS_DENIED = 1n
let error_COULD_NOT_GET_ENTRYPOINT = 2n
let error_COLLISION = 3n
let error_NOT_ENOUGH_ALLOWANCE = 4n
let error_CALL_VIEW_FAILED = 5n
let error_INACTIVE_CONTRACT = 6n 

(* =============================================================================
 * Auxiliary Functions
 * ============================================================================= *)

(* for retiring carbon credits *)
// generates the transactions to retire credits
let param_to_burn (r : retire) : operation = 
    // ensure only the owner can burn his/her tokens
    let owner = Tezos.source in 
    // get op data
    let txndata_burn : mintburn = 
        [ { owner = owner; token_id = r.token_id; qty = r.qty } ; ] in
    let entrypoint_burn =
        match (Tezos.get_entrypoint_opt "%burn" r.project_address : mintburn contract option) with 
        | None -> (failwith error_COULD_NOT_GET_ENTRYPOINT : mintburn contract)
        | Some c -> c in 
    // create the operation
    Tezos.transaction txndata_burn 0tez entrypoint_burn

// records the retired carbon 
let record_retired_carbon (retired_tokens, r : (address, retired_tokens) big_map * retire) : (address, retired_tokens) big_map = 
    // register the retired tokens 
    let (token_owner, token, qty, time_retired) 
        = (Tezos.source, { token_address = r.project_address ; token_id = r.token_id ; }, r.qty, Tezos.now) in 
    let new_retired_tokens = 
        let new_retired_token = { token_owner = token_owner ; token = token ; qty = qty ; time_retired = time_retired } in
        match Big_map.find_opt token_owner retired_tokens with 
        | None -> [ new_retired_token ; ]
        | Some l -> new_retired_token :: l in
    Big_map.update token_owner (Some new_retired_tokens) retired_tokens

(* for upgradeability *)
// returns true if the address is a proxy contract
let is_proxy (addr : address) (directory : address) : bool = 
    match (Tezos.call_view "is_proxy" addr directory : bool option) with 
    | None -> (failwith error_CALL_VIEW_FAILED : bool)
    | Some b -> b

// returns true if the address given has permissions to view/update big maps (for upgrading)
let big_map_permissions (sender_ : address) (storage : storage) : bool = 
    // only proxy contracts can call this
    match storage.next_storage_contract with 
    | None -> // this is the active storage contract, and only other proxy contracts can call this
        is_proxy sender_ storage.directory
    | Some addr_next_storage -> 
        // this is not the active storage contract, so only the next storage contract in the chain can call this
        // this happens when the storage is upgraded
        sender_ = addr_next_storage

(* =============================================================================
 * Entrypoint Functions
 * ============================================================================= *)

(* ====== 
    Create a Project (FA2 contract)
 * ====== *)
let create_project (param : create_project) (storage : storage) : result = 
    let (token_metadata, metadata) = param in 
    // contract must be active 
    if not storage.is_active then (failwith error_INACTIVE_CONTRACT : result) else
    // get new project owner
    let owner = Tezos.source in 
    // check the project owner doesn't already have a project 
    if Big_map.mem owner storage.projects then (failwith error_COLLISION : result) else
    // construct the initial storage for your project's FA2 contract
    let ledger    = (Big_map.empty : (fa2_owner * fa2_token_id , fa2_amt) big_map) in 
    let operators = (Big_map.empty : (fa2_owner * fa2_operator * fa2_token_id, nat) big_map) in  
    let token_metadata = 
        List.fold_left 
        (fun (acc, c : ((fa2_token_id, token_metadata) big_map) * create ) 
            -> Big_map.update c.token_id (Some c) acc ) // ensures no duplicate token ids 
        (Big_map. empty : (fa2_token_id, token_metadata) big_map)
        token_metadata in 
    // initiate an FA2 contract w/permissions given to project contract
    let fa2_init_storage = {
        oracle_contract = Tezos.self_address ;
        owner = owner ; 
        ledger = ledger ;
        operators = operators ;
        token_metadata = token_metadata ; 
        metadata = metadata ;} in 
    let (op_new_fa2,addr_new_fa2) = 
        deploy_carbon_fa2 (None : key_hash option) 0tez fa2_init_storage in
    // update the local storage
    let storage = { storage with 
        projects = Big_map.update owner (Some addr_new_fa2) storage.projects ; } in 
    ([ op_new_fa2 ; ], storage)

(* ====== 
    Mint Carbon Tokens
 * ====== *)
let mint_tokens (param : mint_tokens) (storage : storage) : result =    
    // contract must be active 
    if not storage.is_active then (failwith error_INACTIVE_CONTRACT : result) else
    let proj_owner = Tezos.sender in 
    let addr_proj =
        match Big_map.find_opt proj_owner storage.projects with
        | None -> (failwith error_PROJECT_NOT_FOUND : address)
        | Some a -> a in 
    // check permissions and update storage.minting_permissions to reflect minted tokens
    let storage =
        List.fold_left
        (fun (s, m : storage * mint) -> 
            let token = { token_address = addr_proj ; token_id = m.token_id ; } in 
            let new_allowance = 
                match Big_map.find_opt token s.minting_permissions with 
                | None -> 0n - m.qty
                | Some b -> b - m.qty in 
            if new_allowance < 0 then (failwith error_NOT_ENOUGH_ALLOWANCE : storage) else 
            { s with minting_permissions = Big_map.update token (Some (abs new_allowance)) s.minting_permissions ; })
        storage
        param in 
    // mint tokens
    let txndata_mint = param in 
    let entrypoint_mint =
        match (Tezos.get_entrypoint_opt "%mint" addr_proj : mint_tokens contract option) with 
        | None -> (failwith error_COULD_NOT_GET_ENTRYPOINT : mint_tokens contract)
        | Some c -> c in 
    let op_mint = Tezos.transaction txndata_mint 0tez entrypoint_mint in 
    ([ op_mint ;], storage)

(* ====== 
    Retire Carbon Credits
 * ====== *)
let retire_tokens (param : retire_tokens) (storage : storage) : result = 
    // contract must be active 
    if not storage.is_active then (failwith error_INACTIVE_CONTRACT : result) else
    let ops_burn = List.map param_to_burn param in 
    ops_burn,
    { storage with retired_tokens = List.fold record_retired_carbon param storage.retired_tokens ; }

(* ====== 
    Approve a Project's Tokens (giving it minting rights)
 * ====== *)
let approve_tokens (param : approve_tokens) (storage : storage) : result = 
    // contract must be active 
    if not storage.is_active then (failwith error_INACTIVE_CONTRACT : result) else
    // check permissions
    if Tezos.sender <> storage.admin then (failwith error_PERMISSIONS_DENIED : result) else
    // update storage
    let storage = 
        List.fold_left
        (fun (s, t : storage * approve_token) -> 
            { s with 
                minting_permissions = 
                let new_allowance = 
                    match Big_map.find_opt t.token s.minting_permissions with 
                    | None -> 0n + t.allowance
                    | Some b -> b + t.allowance in 
                Big_map.update t.token (Some new_allowance) storage.minting_permissions } )
        storage
        param in 
    ([] : operation list), storage

(* === === === === === === === ===
    For Contract Upgradeability 
   === === === === === === === === *)
//  the directory contract can de/activate this contract
let activate (b : bool) (storage : storage) : result = 
    if Tezos.sender <> storage.directory then (failwith error_PERMISSIONS_DENIED : result) else
    ([] : operation list),
    { storage with is_active = b ; }

// this is so that future storage contracts can lazily import these big maps 
let proxy_update_ledger (param : proxy_update_ledger) (storage : storage) : result = 
    // check permissions; this can either be called by a current proxy contract or the upgraded storage contract
    if not big_map_permissions Tezos.sender storage then (failwith error_PERMISSIONS_DENIED : result) else
    // proxy contracts can update the ledger; this will be used for contract upgradeability
    match param with 
    | Projects p -> 
        let projects = Big_map.update p.project_owner p.project_address_opt storage.projects in 
        ([] : operation list),
        { storage with projects = projects ; }
    | ProjectsUnit p -> 
        let projects_unit = Big_map.update p.project_address p.exists_opt storage.projects_unit in 
        ([] : operation list),
        { storage with projects_unit = projects_unit ; }
    | MintingPermissions p ->
        let minting_permissions = Big_map.update p.token p.qty_mintable_opt storage.minting_permissions in 
        ([] : operation list),
        { storage with minting_permissions = minting_permissions ; }

(* =============================================================================
 * Contract Views
 * ============================================================================= *)

// we need to expose the storage to future storage contracts/proxy contracts
[@view] let view_projects (project_owner, storage : project_owner * storage) : project_address option = 
    Big_map.find_opt project_owner storage.projects

[@view] let view_projects_unit (project_address, storage : project_address * storage) : unit option = 
    Big_map.find_opt project_address storage.projects_unit

[@view] let view_minting_permissions (token, storage : token * storage) : nat option = 
    Big_map.find_opt token storage.minting_permissions

[@view] let view_admin (_, storage : unit * storage) : address = storage.admin

(* =============================================================================
 * Main
 * ============================================================================= *)

// One calls an entrypoint by sending a transaction with a parameter which can 
//   be matched to one of these patterns specified below.
// The main function matches the pattern and executes the corresponding 
//   entrypont function.
let main (entrypoint, storage : entrypoint * storage) : result =
    match entrypoint with 
    // create a new project; anyone can do this
    | CreateProject param ->
        create_project param storage
    // mint tokens for your project; you need permissions to do this
    | MintTokens param ->
        mint_tokens param storage
    // Retire carbon tokens 
    | RetireTokens param ->
        retire_tokens param storage
    // give permissions to mint tokens 
    | ApproveTokens param -> 
        approve_tokens param storage
    (* for contract upgradeability *)
    | Activate b -> 
        activate b storage
    | ProxyUpdateLedger param -> 
        proxy_update_ledger param storage