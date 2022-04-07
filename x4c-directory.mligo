// This is the permanent contract for the 4C Carbon Credits smart contracts

(* If we wish governance to be able to pause service by "Deactivating" contracts *)
#define DEACTIVATE

(* =============================================================================
 * Storage
 * ============================================================================= *)

type storage = {
    proxy_addresses : (string, address) big_map ; // addresses of proxy contracts, including entrypoints, "storage", and "governance"
    proxy_addresses_unit : (address, unit) big_map ; // used to check if an address is a proxy address 
}

type result = operation list * storage 


(* =============================================================================
 * Entrypoint Type Definition
 * ============================================================================= *)

type new_proxy = {
    proxy_name : string ;
    proxy_addr : address ; }
type existing_proxy = {
    proxy_name : string ;
    new_proxy_addr : address ; }
type remove_proxy = string 
type disburse_funds = {
    to_ : address ; 
    amt_ : tez ; }
#if DEACTIVATE
type deactivate = string list // emergency "kill switch". Activity can be resumed only by an upgrade.
#endif

type entrypoint = 
| AddNewProxy of new_proxy
| UpdateExistingProxy of existing_proxy
| RemoveProxy of remove_proxy
| DisburseFunds of disburse_funds
#if DEACTIVATE
| Deactivate of deactivate
#endif

(* =============================================================================
 * Error Codes
 * ============================================================================= *)

let error_PERMISSIONS_DENIED = 0n
let error_NO_PROXY_FOUND = 1n
let error_COLLISION = 2n
let error_NO_ADDRESS_FOUND = 3n

(* =============================================================================
 * Aux Functions
 * ============================================================================= *)

let is_governance (addr : address) (proxy_addresses : (string, address) big_map) : bool = 
    match Big_map.find_opt "governance" proxy_addresses with
    | None -> true // this is for bootstrapping governance
    | Some addr_governance -> addr = addr_governance

let is_proxy_name (proxy_name : string) (proxy_addresses : (string, address) big_map) : bool = 
    match Big_map.find_opt proxy_name proxy_addresses with 
    | None -> false
    | Some _ -> true

let is_proxy_addr (proxy_addr : address) (proxy_addresses_unit : (address, unit) big_map) : bool = 
    match Big_map.find_opt proxy_addr proxy_addresses_unit with 
    | None -> false
    | Some _ -> true

let record_proxy (proxy_name : string) (proxy_addr : address) (storage : storage) : storage = 
    { storage with
        proxy_addresses = Big_map.add proxy_name proxy_addr storage.proxy_addresses ;
        proxy_addresses_unit = Big_map.add proxy_addr () storage.proxy_addresses_unit ;
    }

let remove_proxy (proxy_name : string) (proxy_addr : address) (storage : storage) : storage = 
    { storage with
        proxy_addresses = Big_map.remove proxy_name storage.proxy_addresses ;
        proxy_addresses_unit = Big_map.remove proxy_addr storage.proxy_addresses_unit ;
    }

(* =============================================================================
 * Entrypoint Functions
 * ============================================================================= *)

let add_new_proxy (p : new_proxy) (storage : storage) : result = 
    let (proxy_name, proxy_addr) = (p.proxy_name, p.proxy_addr) in 
    // check it's coming from the governance smart contract
    if not is_governance Tezos.sender storage.proxy_addresses then (failwith error_PERMISSIONS_DENIED : result) else
    // check the proxy name doesn't already exist 
    if is_proxy_name proxy_name storage.proxy_addresses || is_proxy_addr proxy_addr storage.proxy_addresses_unit
        then (failwith error_COLLISION : result ) else 
    // add the proxy to storage
    let storage = record_proxy proxy_name proxy_addr storage in 
    // activate the new proxy contract 
    let op_activate_new = 
        match (Tezos.get_entrypoint_opt "%activate" proxy_addr : bool contract option) with
        | None -> (failwith error_NO_PROXY_FOUND : operation)
        | Some proxy_contract -> Tezos.transaction true 0tez proxy_contract in 
    [ op_activate_new ; ],
    storage 

let update_existing_proxy (p : existing_proxy) (storage : storage) : result = 
    let (proxy_name, new_proxy_addr) = (p.proxy_name, p.new_proxy_addr) in 
    // check it's coming from the governance smart contract
    if not is_governance Tezos.sender storage.proxy_addresses then (failwith error_PERMISSIONS_DENIED : result) else
    // check the proxy is indeed existing 
    match Big_map.find_opt proxy_name storage.proxy_addresses with
    | None -> (failwith error_NO_PROXY_FOUND : result)
    | Some old_proxy_addr -> (
        // update the proxy address
        let proxy_addresses = Big_map.update proxy_name (Some new_proxy_addr) storage.proxy_addresses in 
        // remove the old address from proxy_addresses_unit and add the new one 
        let proxy_addresses_unit = Big_map.remove old_proxy_addr storage.proxy_addresses_unit in 
        let proxy_addresses_unit = Big_map.add new_proxy_addr () proxy_addresses_unit in 
        // deactivate the old contracts and activate the new
        let op_deactivate_old = 
            match (Tezos.get_entrypoint_opt "%activate" old_proxy_addr : bool contract option) with
            | None -> (failwith error_NO_PROXY_FOUND : operation)
            | Some old_proxy_contract -> Tezos.transaction false 0tez old_proxy_contract in 
        let op_activate_new = 
            match (Tezos.get_entrypoint_opt "%activate" new_proxy_addr : bool contract option) with
            | None -> (failwith error_NO_PROXY_FOUND : operation)
            | Some new_proxy_contract -> Tezos.transaction true 0tez new_proxy_contract in 
        if p.proxy_name = "storage" then
            // we need to fetch the storage too 
            let op_fetch_storage = 
                match (Tezos.get_entrypoint_opt "%fetchStorage" new_proxy_addr : unit contract option) with
                | None -> (failwith error_NO_PROXY_FOUND : operation)
                | Some entrypoint_addr -> Tezos.transaction () 0tez entrypoint_addr in
            [ op_deactivate_old ; op_fetch_storage ; op_activate_new ; ],
            { storage with 
                proxy_addresses = proxy_addresses ; 
                proxy_addresses_unit = proxy_addresses_unit ; }
        else 
            [ op_deactivate_old ; op_activate_new ; ],
            { storage with 
                proxy_addresses = proxy_addresses ; 
                proxy_addresses_unit = proxy_addresses_unit ; }
    )

let remove_proxy (p : remove_proxy) (storage : storage) : result = 
    let proxy_name = p in 
    // check it's coming from the governance smart contract
    if not is_governance Tezos.sender storage.proxy_addresses then (failwith error_PERMISSIONS_DENIED : result) else
    // the goverannce and storage contracts cannot be removed 
    if proxy_name = "governance" || proxy_name = "storage" then (failwith error_PERMISSIONS_DENIED : result) else
    // remove the proxy
    match Big_map.find_opt proxy_name storage.proxy_addresses with 
    | None -> (failwith error_NO_PROXY_FOUND : result)
    | Some proxy_addr -> (
        let storage = remove_proxy proxy_name proxy_addr storage in 
        // deactivate the old contract
        let op_deactivate_old = 
            match (Tezos.get_entrypoint_opt "%activate" proxy_addr : bool contract option) with
            | None -> (failwith error_NO_PROXY_FOUND : operation)
            | Some proxy_contract -> Tezos.transaction false 0tez proxy_contract in 
        [ op_deactivate_old ; ],
        storage
    )

let disburse_funds (p : disburse_funds) (storage : storage) : result = 
    let (to_, amt_) = (p.to_, p.amt_) in 
    // check it's coming from a proxy address
    if not is_proxy_addr Tezos.sender storage.proxy_addresses_unit then (failwith error_PERMISSIONS_DENIED : result) else
    // disburse funds 
    match (Tezos.get_contract_opt to_ : unit contract option) with 
    | None -> (failwith error_NO_ADDRESS_FOUND : result)
    | Some addr_contract -> 
        [ Tezos.transaction () amt_ addr_contract ; ],
        storage

#if DEACTIVATE
let deactivate (p : deactivate) (storage : storage) : result = 
    // check it's coming from governance 
    if not is_governance Tezos.sender storage.proxy_addresses then (failwith error_PERMISSIONS_DENIED : result) else
    List.map
    ( fun (proxy_name : string) : operation -> 
        match Big_map.find_opt proxy_name storage.proxy_addresses with 
        | None -> (failwith error_NO_PROXY_FOUND : operation)
        | Some proxy_addr -> (
            match (Tezos.get_entrypoint_opt "%activate" proxy_addr : bool contract option) with 
            | None -> (failwith error_NO_ADDRESS_FOUND : operation)
            | Some proxy_entrypoint -> Tezos.transaction false 0tez proxy_entrypoint ) )
    p,
    storage
#endif


(* =============================================================================
 * Contract Views
 * ============================================================================= *)

[@view] let get_proxy (proxy_name, storage : string * storage) : address = 
    match Big_map.find_opt proxy_name storage.proxy_addresses with 
    | None -> (failwith error_NO_PROXY_FOUND : address)
    | Some a -> a

[@view] let is_proxy (proxy_addr, storage : address * storage) : bool = 
    Big_map.mem proxy_addr storage.proxy_addresses_unit 

(* =============================================================================
 * Main Function
 * ============================================================================= *)

let main (param, storage : entrypoint * storage) : result = 
    match param with 
    | AddNewProxy p -> 
        add_new_proxy p storage
    | UpdateExistingProxy p ->
        update_existing_proxy p storage
    | RemoveProxy p ->
        remove_proxy p storage
    | DisburseFunds p ->
        disburse_funds p storage
#if DEACTIVATE
    | Deactivate p ->
        deactivate p storage
#endif