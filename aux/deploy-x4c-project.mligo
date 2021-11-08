#include "x4c-project-types.mligo"
type storage_fa2 = storage

let deploy_carbon_fa2 (delegate : key_hash option) (amnt : tez) (init_storage : storage_fa2) = 
    Tezos.create_contract
    (fun (entrypoint, storage : entrypoint * storage) : result ->
        let error_FA2_TOKEN_UNDEFINED = 0n in 
        let error_FA2_INSUFFICIENT_BALANCE = 1n in
        let error_FA2_NOT_OPERATOR = 4n in
        let error_PERMISSIONS_DENIED = 10n in
        let error_COLLISION = 12n in 
        let rec main (entrypoint, storage : entrypoint * storage) : result = (
            match entrypoint with
            | Transfer param -> (
                let rec transfer_txn (param , storage : transfer * storage) : storage = 
                    match param.txs with
                    | [] -> storage
                    | hd :: tl ->
                        let (from, to, token_id, qty) = (param.from_, hd.to_, hd.token_id, hd.amount) in 
                        // check permissions
                        let operator = Tezos.sender in 
                        let owner = from in 
                        let operator_permissions = 
                            match Big_map.find_opt (owner, operator, token_id) storage.operators with 
                            | None -> 0n
                            | Some allowed_qty -> allowed_qty in 
                        if ((Tezos.sender <> from) && (operator_permissions < qty)) then (failwith error_FA2_NOT_OPERATOR : storage) else 
                        // update operator permissions to reflect this transfer
                        let operators = 
                            if Tezos.sender <> from // thus this is an operator
                            then Big_map.update (owner, operator, token_id) (Some (abs (operator_permissions - qty))) storage.operators
                            else storage.operators in
                        // check balance
                        let sender_token_balance =
                            match Big_map.find_opt (from, token_id) storage.ledger with
                            | None -> 0n
                            | Some token_balance -> token_balance in
                        let recipient_balance = 
                            match Big_map.find_opt (to, token_id) storage.ledger with
                            | None -> 0n
                            | Some recipient_token_balance -> recipient_token_balance in
                        if (sender_token_balance < qty) then (failwith error_FA2_INSUFFICIENT_BALANCE : storage) else
                        // update the ledger
                        let ledger = 
                            Big_map.update
                            (to, token_id)
                            (Some (recipient_balance + qty))
                                (Big_map.update 
                                (from, token_id) 
                                (Some (abs (sender_token_balance - qty))) 
                                storage.ledger) in 
                        let storage = {storage with ledger = ledger ; operators = operators ; } in                        let param = { from_ = from ; txs = tl ; } in 
                        transfer_txn (param, storage) in 
                match param with 
                | [] -> (([] : operation list), storage)
                | hd :: tl -> 
                    let storage = transfer_txn (hd, storage) in 
                    main (Transfer(tl), storage))
            | Balance_of param -> (
                let (request_list, callback) = (param.requests, param.callback) in 
                let accumulator = ([] : callback_data list) in
                let rec owner_and_id_to_balance (param : (callback_data list) * (requests list) * ((fa2_owner * fa2_token_id , fa2_amt) big_map)) : callback_data list =
                    let (accumulator, request_list, ledger) = param in
                    match request_list with
                    | [] -> accumulator 
                    | h :: t -> 
                        let owner = h.owner in 
                        let token_id = h.token_id in
                        let qty =
                            match Big_map.find_opt (owner, token_id) ledger with 
                            | None -> 0n
                            | Some owner_balance -> owner_balance in
                        let request = { owner = owner ; token_id = token_id ; } in
                        let accumulator = { request = request ; balance = qty ; } :: accumulator in
                        owner_and_id_to_balance (accumulator, t, ledger) in 
                let ack_list = owner_and_id_to_balance (accumulator, request_list, storage.ledger) in
                let t = Tezos.transaction ack_list 0mutez callback in
                ([t], storage))
            | Update_operators param -> (
                let update_operator (param : update_operator) (storage : storage) : storage = 
                    match param with
                    | Add_operator o ->
                        let (owner, operator, token_id, qty) = (o.owner, o.operator, o.token_id, o.qty) in 
                        // check permissions        
                        if (Tezos.source <> owner) then (failwith error_PERMISSIONS_DENIED : storage) else
                        // update storage
                        let new_qty = 
                            let old_qty = 
                            match Big_map.find_opt (owner, operator, token_id) storage.operators with 
                            | None -> 0n 
                            | Some q -> q in 
                            old_qty + qty in 
                        let storage = {storage with 
                            operators = Big_map.update (owner, operator, token_id) (Some new_qty) storage.operators ; } in 
                        storage
                    | Remove_operator o ->
                        let (owner, operator, token_id) = (o.owner, o.operator, o.token_id) in 
                        // check permissions
                        if (Tezos.sender <> owner) then (failwith error_PERMISSIONS_DENIED : storage) else
                        // update storage
                        let storage = {storage with 
                            operators = Big_map.update (owner,operator,token_id) (None : nat option) storage.operators ; } in 
                        storage in 
                match param with
                | [] -> (([] : operation list), storage)
                | hd :: tl -> 
                    let storage = update_operator hd storage in 
                    main (Update_operators(tl), storage))
            | Mint param -> (
                let minting_list = param in
                match minting_list with 
                | [] -> (([] : operation list), storage)
                | hd :: tl -> 
                    let owner = hd.owner in 
                    let token_id = hd.token_id in 
                    let qty = hd.qty in 
                    // check operator
                    if Tezos.sender <> storage.carbon_contract then (failwith error_PERMISSIONS_DENIED : result) else 
                    // update owner balance
                    let owner_balance = 
                        match Big_map.find_opt (owner, token_id) storage.ledger with
                        | None -> 0n + qty
                        | Some ownerPrevBalance -> ownerPrevBalance + qty in
                    let storage = {storage with 
                        ledger = Big_map.update (owner, token_id) (Some owner_balance) storage.ledger ; } in 
                    main (Mint(tl), storage))
            | Burn param -> (
                // check permissions
                if Tezos.sender <> storage.carbon_contract then (failwith error_PERMISSIONS_DENIED : result) else 
                let burn_addr = ("tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU" : address) in 
                let from = Tezos.source in 
                // transfer the tokens to the burn address
                let txndata_burn = {
                    from_ = from ;
                    txs = List.map
                        (fun (b : mintburn_data) : transfer_to -> 
                            let () = assert (b.owner = from) in 
                            {
                                to_ = burn_addr ;
                                token_id = b.token_id ;
                                amount = b.qty ;
                            })
                        param ;
                } in 
                main (Transfer([txndata_burn]), storage))
            | Get_metadata param -> (
                let query_list = param.token_ids in 
                let callback = param.callback in 
                let metadata_list = 
                    List.map 
                    (fun (token_id : nat) : token_metadata -> 
                        match Big_map.find_opt token_id storage.token_metadata with 
                        | None -> (failwith error_FA2_TOKEN_UNDEFINED : token_metadata) 
                        | Some m -> {token_id = token_id ; token_info = m.token_info ; })
                    query_list in 
                let op_metadata = Tezos.transaction metadata_list 0tez callback in 
                ([op_metadata] , storage)) 
            | Add_zone param -> (
                if Tezos.sender <> storage.owner then (failwith error_PERMISSIONS_DENIED : result) else
                let storage = 
                    List.fold_left
                    (fun (s, d : storage * token_metadata) -> 
                        { s with token_metadata = 
                            match Big_map.get_and_update d.token_id (Some d) s.token_metadata with
                            | (None, m) -> m
                            | (Some _, m) -> (failwith error_COLLISION : (fa2_token_id, token_metadata) big_map) } )
                    storage
                    param in 
                ([] : operation list), storage)
                
            | Update_contract_metadata param -> (
                if Tezos.sender <> storage.owner then (failwith error_PERMISSIONS_DENIED : result) else
                ([] : operation list),
                { storage with metadata = param } ) ) in
        main (entrypoint, storage))
        (* End of contract code for the project FA2 contract *)
    delegate
    amnt 
    init_storage
    

