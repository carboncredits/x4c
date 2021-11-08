(* This is the orderbook exchange that services the carbon contract *)
(* The structure is a double-sided auction *)
#include "aux/x4c-project-types.mligo"

(* =============================================================================
 * Storage
 * ============================================================================= *)

type token = { token_address : address ; token_id : nat ; }

type token_for_sale = {
    owner : address ; 
    token_address : address ; 
    token_id : nat ; 
    qty : nat ;
    batch_number : nat ; // to avoid collisions; default is 0n
}
type sale_data = { price : nat ; }

type token_offer = {
    owner : address ; 
    token_address : address ; 
    token_id : nat ; 
    qty : nat ;
    offering_party : address ; 
}
type offer_data = { quote : nat ; }

type init_auction_data = {
    deadline : timestamp ; // the end of an auction
    reserve_price : nat ; // in mutez
}
type auction_data = { 
    leader : address ; 
    leading_bid : nat ; // the leader's bid 
    deadline : timestamp ; // the end of the auction
    reserve_price : nat ; // in mutez
}

type init_blind_auction_data = {
    deadline : timestamp ; // the end of the auction 
    private_unlock_pd : int ; // a bidder unlocks their own bid
    reserve_price : nat ; // in mutez
    bid_deposit : nat ; // the desposit (in XTZ) required to bid
}
type blind_auction_data = {
    // timekeeping
    deadline : timestamp ; // the end of the auction 
    private_unlock_pd : int ; // period of time a bidder unlocks their own bid (seconds)
    // auction price parameters
    reserve_price : nat ; // in mutez
    bid_deposit : nat ; // the desposit (in XTZ) required to submit a bid
    // bidding leaderboard
    leader : address ; 
    leading_bid : nat ; // the leader's bid
}

type redeemable_token = {
    token_address : address ; 
    token_id : nat ; 
    qty : nat ;
}
type redeemable = 
| Tokens of redeemable_token 
| XTZ of nat 

type storage = {
    // manages different kinds of auctions
    tokens_for_sale : (token_for_sale, sale_data) big_map ;
    offers : (token_offer, offer_data) big_map ;
    tokens_on_auction : (token_for_sale, auction_data) big_map ;
    tokens_on_blind_auction : (token_for_sale, blind_auction_data) big_map ;
    bids_on_blind_auction : (address * token_for_sale, chest) big_map ;
    redeem : (address, redeemable list) big_map ;
    // metadata and minting oracle
    carbon_contract : address ;
    // the tokens that are allowed to be traded on this marketplace
    approved_tokens : (token, unit) big_map ; 
    // for bootstrapping
    null_address : address ;
}

(* =============================================================================
 * Entrypoint Type Definition
 * ============================================================================= *)

type buy_for_sale = { buyer : address ; token : token ; owner : address ; amt : nat ; }
type approve_tokens = (token * (unit option)) list

type for_sale = 
| PostForSale   of token_for_sale * sale_data
| UnpostForSale of token_for_sale
| BuyForSale    of token_for_sale

type auction = 
| InitiateAuction of token_for_sale * init_auction_data
| BidOnAuction    of token_for_sale
| FinishAuction   of token_for_sale

type initiate_blind_auction = { token : token_for_sale ; init_data : init_blind_auction_data ; }
type bid_on_blind_auction = { token : token_for_sale ; bid : chest ; }
type uncover_bid = { token : token_for_sale ; chest_key : chest_key ; chest_time : nat ; }
type remove_bid = { token : token_for_sale ; bidder : address ; }

type blind_auction = 
| InitiateBlindAuction of initiate_blind_auction
| BidOnBlindAuction  of bid_on_blind_auction
| UncoverBid  of uncover_bid
| RemoveBid   of remove_bid
| FinishBlindAuction of token_for_sale 

type offer = 
| MakeOffer    of token_for_sale
| RetractOffer of token_for_sale
| AcceptOffer  of token_offer * offer_data

type entrypoint = 
| ForSale of for_sale // a seller posts their tokens for sale at a given price
| Auction of auction  // a seller auctions off their tokens
| BlindAuction of blind_auction // a seller auctions off their tokens in a sealed-bid auction
| Offer of offer // a buyer makes an offer for tokens
| Redeem of unit // redeem tokens and xtz for the sender
| ApproveTokens of approve_tokens // updated by the carbon contract

type result = operation list * storage

(* =============================================================================
 * ERROR CODES
 * ============================================================================= *)

let error_PERMISSIONS_DENIED = 0n 
let error_TOKEN_NOT_APPROVED = 1n 
let error_NO_TOKEN_CONTRACT_FOUND = 2n 
let error_INVALID_ADDRESS = 3n
let error_TOKEN_FOR_SALE_NOT_FOUND = 4n
let error_AUCTION_IS_OVER = 5n
let error_AUCTION_NOT_OVER = 6n
let error_AUCTIONED_TOKEN_NOT_FOUND = 7n
let error_BID_TOO_LOW = 8n
let error_INVALID_DEADLINE = 9n
let error_OFFER_ALREADY_MADE = 10n
let error_NO_OFFER_FOUND = 11n
let error_OFFER_MUST_BE_NONZERO = 12n
let error_INSUFFICIENT_FUNDS = 13n
let error_COLLISION = 14n
let error_INCORRECT_DEPOSIT = 15n
let error_BID_NOT_FOUND = 16n
let error_NOT_PRIVATE_UNLOCK_PERIOD = 17n
let error_COULD_NOT_DECRYPT_BID = 18n
let error_TIMELOCK = 19n
let error_PRIVATE_UNLOCK_PD_MUST_BE_POSITIVE = 20n
let error_INCORRECT_BID_AMOUNT = 21n

(* =============================================================================
 * Aux Functions
 * ============================================================================= *)

let to_redeem (redeeming_party : address) (tokens : redeemable) (redeem : (address, redeemable list) big_map) : (address, redeemable list) big_map = 
    let old_redeemable = match Big_map.find_opt redeeming_party redeem with 
    | None -> ([] : redeemable list)
    | Some l -> l in 
    let updated_redeemable = tokens :: old_redeemable in 
    Big_map.update redeeming_party (Some updated_redeemable) redeem


(* =============================================================================
 * Entrypoint Functions
 * ============================================================================= *)

(*** ** 
 ForSale Entrypoint Functions 
 *** **)
let post_for_sale (token, data : token_for_sale * sale_data) (storage : storage) : result = 
    // check permissions and collisions
    if token.owner <> Tezos.sender then (failwith error_PERMISSIONS_DENIED : result) else
    if Big_map.mem token storage.tokens_for_sale then (failwith error_COLLISION : result) else
    // check the token is approved
    let token_data : token = { token_address = token.token_address ; token_id = token.token_id ; } in 
    if not Big_map.mem token_data storage.approved_tokens then (failwith error_TOKEN_NOT_APPROVED : result) else
    // receive the tokens; sender has to authorize this as an operator
    let txndata_receive_tokens = { 
        from_ = Tezos.sender ; 
        txs = [ { to_ = Tezos.self_address ; token_id = token.token_id ; amount = token.qty ; } ; ] ; } in
    let entrypoint_receive_tokens =
        match (Tezos.get_entrypoint_opt "%transfer" token.token_address : transfer list contract option) with 
        | None -> (failwith error_NO_TOKEN_CONTRACT_FOUND : transfer list contract)
        | Some e -> e in
    let op_receive_tokens = 
        Tezos.transaction [txndata_receive_tokens] 0tez entrypoint_receive_tokens in 
    // update storage 
    let tokens_for_sale = Big_map.update token (Some data) storage.tokens_for_sale in 
    // output
    [op_receive_tokens], 
    { storage with tokens_for_sale = tokens_for_sale ; }


let unpost_for_sale (token : token_for_sale) (storage : storage) : result = 
    // check permissions
    if token.owner <> Tezos.sender then (failwith error_PERMISSIONS_DENIED : result) else
    // check the token is actually for sale; if it is, remove it from storage.tokens_for_sale
    let (_, updated_tokens_for_sale) : sale_data * (token_for_sale, sale_data) big_map =
        match Big_map.get_and_update token (None : sale_data option) storage.tokens_for_sale with
        | (None, _) -> (failwith error_TOKEN_FOR_SALE_NOT_FOUND : sale_data * (token_for_sale, sale_data) big_map)
        | (Some d, s) -> (d, s) in
    // send the token back 
    let txndata_return_tokens = { 
        from_ = Tezos.self_address ; 
        txs = [ { to_ = token.owner ; token_id = token.token_id ; amount = token.qty ; } ; ] ; } in
    let entrypoint_return_tokens =
        match (Tezos.get_entrypoint_opt "%transfer" token.token_address : transfer list contract option) with 
        | None -> (failwith error_NO_TOKEN_CONTRACT_FOUND : transfer list contract)
        | Some e -> e in 
    let op_return_tokens = 
        Tezos.transaction [txndata_return_tokens] 0tez entrypoint_return_tokens in 
    // output
    [op_return_tokens], 
    {storage with tokens_for_sale = updated_tokens_for_sale ;}


let buy_for_sale (token: token_for_sale) (storage : storage) : result = 
    let buyer = Tezos.sender in 
    // verify token is for sale and buyer has sent enough xtz
    // if everything checks out, update the storage
    let (price, updated_tokens_for_sale) : nat * (token_for_sale, sale_data) big_map =
        match Big_map.get_and_update token (None : sale_data option) storage.tokens_for_sale with
        | (None, _) -> (failwith error_TOKEN_FOR_SALE_NOT_FOUND : nat * (token_for_sale, sale_data) big_map) 
        | (Some s, u) -> (s.price, u) in 
    if Tezos.amount < price * 1mutez then (failwith error_INSUFFICIENT_FUNDS : result) else
    // send the tokens to the buyer
    let txndata_send_tokens = {
        from_ = Tezos.self_address ; 
        txs = [ { to_ = buyer ; token_id = token.token_id ; amount = token.qty ; } ; ] ; } in 
    let entrypoint_send_tokens =
        match (Tezos.get_entrypoint_opt "%transfer" token.token_address : transfer list contract option) with 
        | None -> (failwith error_NO_TOKEN_CONTRACT_FOUND : transfer list contract)
        | Some e -> e in 
    let op_send_tokens = 
        Tezos.transaction [txndata_send_tokens] 0tez entrypoint_send_tokens in 
    // send the XTZ along to the seller (owner)
    let entrypoint_pay_seller =
        match (Tezos.get_contract_opt token.owner : unit contract option) with 
        | None -> (failwith error_INVALID_ADDRESS : unit contract)
        | Some e -> e in 
    let op_pay_seller = Tezos.transaction () (price * 1mutez) entrypoint_pay_seller in 
    // output
    [op_send_tokens ; op_pay_seller ;], 
    {storage with tokens_for_sale = updated_tokens_for_sale ;}

let for_sale (param : for_sale) (storage : storage) : result = 
    match param with
    | PostForSale p -> 
        post_for_sale p storage
    | UnpostForSale p ->
        unpost_for_sale p storage
    | BuyForSale p ->  
        buy_for_sale p storage


(*** **
 Auction Entrypoint Functions 
 *** **)
//  Permisions:
//  - if a wallet is an operator for someone's tokens, they can initiate an auction on their behalf
let initiate_auction (token, data : token_for_sale * init_auction_data) (storage : storage) : result = 
    // check the deadline is not already passed, for collisions, and that the token is approved
    if data.deadline <= Tezos.now then (failwith error_INVALID_DEADLINE : result) else
    if Big_map.mem token storage.tokens_on_auction then (failwith error_COLLISION : result) else
    if not Big_map.mem {token_address = token.token_address ; token_id = token.token_id ; } storage.approved_tokens then (failwith error_TOKEN_NOT_APPROVED : result) else
    // receive the tokens
    let txndata_receive_tokens = { 
        from_ = token.owner ; // if Tezos.sender is not an operator this will fail
        txs = [ { to_ = Tezos.self_address ; token_id = token.token_id ; amount = token.qty ; } ; ] ; } in
    let entrypoint_receive_tokens =
        match (Tezos.get_entrypoint_opt "%transfer" token.token_address : transfer list contract option) with 
        | None -> (failwith error_NO_TOKEN_CONTRACT_FOUND : transfer list contract)
        | Some e -> e in
    let op_receive_tokens = 
        Tezos.transaction [txndata_receive_tokens] 0tez entrypoint_receive_tokens in 
    // update the tokens_on_auction big map
    let init_data : auction_data = {
        leader = token.owner ; 
        leading_bid = 0n ;
        deadline = data.deadline ;
        reserve_price = data.reserve_price ; } in
    // output
    [ op_receive_tokens ; ],
    { storage with tokens_on_auction = Big_map.update token (Some init_data) storage.tokens_on_auction ; }

// Permissions: Anyone but the token owner can bid on an auction 
let bid_on_auction (token : token_for_sale) (storage : storage) : result = 
    // get auction data
    let data =
        match (Big_map.find_opt token storage.tokens_on_auction : auction_data option) with
        | None -> (failwith error_AUCTIONED_TOKEN_NOT_FOUND : auction_data)
        | Some d -> d in 
    // check the deadline is not past and that the bidding party is not the owner
    if data.deadline <= Tezos.now then (failwith error_AUCTION_IS_OVER : result) else 
    if Tezos.sender = token.owner then (failwith error_PERMISSIONS_DENIED : result) else
    // check the bid is sufficiently high
    let bid = Tezos.amount in 
    let no_one_has_bid = (data.leader = token.owner) in 
    // if no one has bid, just make sure the bid is at least the reserve price
    if no_one_has_bid && bid < data.reserve_price * 1mutez 
        then (failwith error_BID_TOO_LOW : result) else
    // if someone else has already bid, then a new bid must go up by at least 1%
    if (not no_one_has_bid) && bid < (data.leading_bid * 1mutez * 101n) / 100n then (failwith error_BID_TOO_LOW : result) else 
    // update the storage to include the new leader
    let tokens_on_auction = 
        Big_map.update 
        token 
        (Some { data with 
            leader = Tezos.sender ; 
            leading_bid = bid / 1mutez ; 
            // add five mins to the deadline for bids made in the last five mins to prevent sniping
            deadline = if data.deadline - Tezos.now < 300 then data.deadline + 300 else data.deadline ; })
        storage.tokens_on_auction in
    // if the bid is higher than the leader's bid, return the leader's cash
    if no_one_has_bid
    then
        ([] : operation list),
        { storage with tokens_on_auction = tokens_on_auction ; }
    else 
        // return the old bid by making it redeemable 
        // if you don't do this and try to include the return in this transaction,
        // a contract that can't receive funds could win all auctions by making it impossible
        // to place a bid above them.
        let redeem = to_redeem data.leader (XTZ(data.leading_bid)) storage.redeem in 
        ([] : operation list), 
        { storage with 
            tokens_on_auction = tokens_on_auction ; 
            redeem = redeem ; }

// this function makes the auctioned tokens and the leading bid redeemable by 
// the leader and token owner, respectively 
// Permissions: only the token owner or the auction leader can finish the auction
let finish_auction (token : token_for_sale) (storage : storage) : result = 
    // find the auction in progress and remove it from storage
    let (data, tokens_on_auction) = match Big_map.get_and_update token (None : auction_data option) storage.tokens_on_auction with
    | (None, t) -> (failwith error_AUCTIONED_TOKEN_NOT_FOUND : auction_data * (token_for_sale, auction_data) big_map)
    | (Some d, t) -> (d, t) in 
    // check the deadline has passed
    if Tezos.now < data.deadline then (failwith error_AUCTION_NOT_OVER : result) else 
    if Tezos.sender <> data.leader && Tezos.sender <> token.owner then (failwith error_PERMISSIONS_DENIED : result) else
    // make the tokens on auction redeemable
    let redeemable_tokens = { token_address = token.token_address ; token_id = token.token_id ; qty = token.qty ; } in 
    let redeem = to_redeem data.leader (Tokens(redeemable_tokens)) storage.redeem in 
    // make the highest bid redeemable
    let redeem = to_redeem token.owner (XTZ(data.leading_bid)) storage.redeem in 
    ([] : operation list),
    { storage with 
        tokens_on_auction = tokens_on_auction ;
        redeem = redeem ; }


let auction (param : auction) (storage : storage) : result = 
    match param with 
    | InitiateAuction p ->
        initiate_auction p storage
    | BidOnAuction p ->
        bid_on_auction p storage 
    | FinishAuction p -> 
        finish_auction p storage

(*** **
 Blind Auction Entrypoint Functions 
 *** **)
let initiate_blind_auction (param : initiate_blind_auction) (storage : storage) : result = 
    let (token, data) = (param.token, param.init_data) in 
    // check the deadline is not already passed, for collisions, and that the token is approved
    if not (Tezos.now < data.deadline) then (failwith error_INVALID_DEADLINE : result) else
    if Big_map.mem token storage.tokens_on_blind_auction then (failwith error_COLLISION : result) else
    if not Big_map.mem {token_address = token.token_address ; token_id = token.token_id ; } storage.approved_tokens 
        then (failwith error_TOKEN_NOT_APPROVED : result) else
    if not data.private_unlock_pd > 0 then (failwith error_PRIVATE_UNLOCK_PD_MUST_BE_POSITIVE : result) else
    // receive the tokens
    let txndata_receive_tokens = { 
        from_ = token.owner ; // if Tezos.sender is not an operator this will fail
        txs = [ { to_ = Tezos.self_address ; token_id = token.token_id ; amount = token.qty ; } ; ] ; } in
    let entrypoint_receive_tokens =
        match (Tezos.get_entrypoint_opt "%transfer" token.token_address : transfer list contract option) with 
        | None -> (failwith error_NO_TOKEN_CONTRACT_FOUND : transfer list contract)
        | Some e -> e in
    let op_receive_tokens = 
        Tezos.transaction [txndata_receive_tokens] 0tez entrypoint_receive_tokens in 
    // update the tokens_on_auction big map
    let init_data : blind_auction_data = {
        // leaderboard
        leader = token.owner ; 
        leading_bid = 0n ;
        // timekeeping
        deadline = data.deadline ;
        private_unlock_pd = data.private_unlock_pd ;
        // price parameters 
        bid_deposit = data.bid_deposit ;
        reserve_price = data.reserve_price ; } in
    // output
    [ op_receive_tokens ; ],
    { storage with tokens_on_blind_auction = Big_map.update token (Some init_data) storage.tokens_on_blind_auction ; }


// A bid is received as an encrypted value; it MUST be an encrypted natural number
// An operation that transfers the bid (and thus back it) is atomically tied to uncovering the bid
let bid_on_blind_auction (param : bid_on_blind_auction) (storage : storage) : result = 
    let (token, bid) = (param.token, param.bid) in 
    // check the bidder isn't the token owner 
    if Tezos.sender = token.owner then (failwith error_PERMISSIONS_DENIED : result) else
    // get the data
    let bid_deposit = Tezos.amount / 1mutez in 
    let data = 
        match Big_map.find_opt token storage.tokens_on_blind_auction with 
        | None -> (failwith error_AUCTIONED_TOKEN_NOT_FOUND : blind_auction_data)
        | Some d -> d in 
    // check that the bid deposit is the right amount
    if bid_deposit <> data.bid_deposit then (failwith error_INCORRECT_DEPOSIT : result) else
    // check for collisions (you can only bid once)
    if Big_map.mem (Tezos.sender, token) storage.bids_on_blind_auction then (failwith error_COLLISION : result) else 
    // update storage to reflect their bid
    ([] : operation list), 
    { storage with 
        bids_on_blind_auction = Big_map.update (Tezos.sender,token) (Some bid) storage.bids_on_blind_auction ; }


// A bidder uncovers their own bid (a nat) and sends the same amount in mutez with the transaction. 
// If the bid:
// - is in the wrong format (doesn't type check with nat), or
// - can't be unlocked for some reason
// then the deposit will be open to anyone who garbage collects at the end of the auction
let uncover_bid (param : uncover_bid) (storage : storage) : result = 
    let (token, chest_key, chest_time) = (param.token, param.chest_key, param.chest_time) in 
    // get the auction data
    let data = 
        match Big_map.find_opt token storage.tokens_on_blind_auction with 
        | None -> (failwith error_AUCTIONED_TOKEN_NOT_FOUND : blind_auction_data)
        | Some d -> d in 
    // check the timeline is right
    if not (data.deadline <= Tezos.now && Tezos.now < data.deadline + data.private_unlock_pd) 
        then (failwith error_NOT_PRIVATE_UNLOCK_PERIOD : result) else
    // get the bid. Tezos.sender can only access their own bid
    // If the bid is in the wrong format, then it can't be unlocked. 
    //   In that case, the collateral will get sent to the null address later
    // The bid gets removed from storage
    let (chest, storage) = 
        match Big_map.get_and_update (Tezos.sender, token) (None : chest option) storage.bids_on_blind_auction with
        | (None, _) -> (failwith error_BID_NOT_FOUND : chest * storage)
        | (Some c, m) -> (c, {storage with bids_on_blind_auction = m ;}) in 
    let bid : nat = 
        match Tezos.open_chest chest_key chest chest_time with 
        | Ok_opening b -> (
            match (Bytes.unpack b : nat option) with 
            | None -> (failwith error_COULD_NOT_DECRYPT_BID : nat)
            | Some n -> n)
        | Fail_decrypt -> (failwith error_COULD_NOT_DECRYPT_BID : nat)
        | Fail_timelock -> (failwith error_TIMELOCK : nat) in 
    // check that the bid is the amount sent with the transaction
    if bid * 1mutez <> Tezos.amount then (failwith error_INCORRECT_BID_AMOUNT : result) else
    // manage the auction
    // case 1: the bidder is the first to uncover their bid 
    let no_one_has_bid : bool = data.leader = token.owner && data.leading_bid = 0n in 
    if no_one_has_bid then (
        // return the bidder's deposit (XTZ)
        let redeem = to_redeem Tezos.sender (XTZ(data.bid_deposit)) storage.redeem in 
        // update the data
        let data = { data with leader = Tezos.sender ; leading_bid = bid ; } in 
        ([] : operation list),
        { storage with 
            tokens_on_blind_auction = Big_map.update token (Some data) storage.tokens_on_blind_auction ; 
            redeem = redeem ; })
    else
    // case 2: the bidder is the new leader
    if bid > data.leading_bid then (
        // return the bidder's deposit (XTZ)
        let redeem = to_redeem Tezos.sender (XTZ(data.bid_deposit)) storage.redeem in 
        // return the bid of the current leader (XTZ)
        let redeem = to_redeem data.leader (XTZ(data.leading_bid)) storage.redeem in 
        // update the data
        let data = { data with leader = Tezos.sender ; leading_bid = bid ; } in 
        ([] : operation list),
        { storage with 
            tokens_on_blind_auction = Big_map.update token (Some data) storage.tokens_on_blind_auction ; 
            redeem = redeem ; })
    // case 3: the bidder is not the new leader
    else ( 
        // do not execute a transfer, or change storage
        // just return the bidder's deposit (XTZ)
        let redeem = to_redeem Tezos.sender (XTZ(data.bid_deposit)) storage.redeem in 
        ([] : operation list),
        {storage 
            with redeem = redeem ; } )

// the bidder forfeits the chance to participate in the auction and loses their bid 
// the party removing the bid has to be able to accept payments in XTZ
let remove_bid (param : remove_bid) (storage : storage) : result = 
    let (token, bidder) = (param.token, param.bidder) in 
    // get the auction data
    let data = 
        match Big_map.find_opt token storage.tokens_on_blind_auction with 
        | None -> (failwith error_AUCTIONED_TOKEN_NOT_FOUND : blind_auction_data)
        | Some d -> d in 
    // check the timeline is right
    if not (Tezos.now >= data.deadline + data.private_unlock_pd) 
        then (failwith error_AUCTION_NOT_OVER : result) else
    // remove the chest from storage
    let (_, storage) = 
        match Big_map.get_and_update (Tezos.sender, token) (None : chest option) storage.bids_on_blind_auction with
        | (None, _) -> (failwith error_BID_NOT_FOUND : chest * storage)
        | (Some c, m) -> (c, {storage with bids_on_blind_auction = m ;}) in 
    // transfer the deposit to the bidder (TODO : HALF OR SOMETHING?)
    let redeem = to_redeem Tezos.sender (XTZ(data.bid_deposit)) storage.redeem in 
    ([] : operation list), 
    {storage with 
        redeem = redeem ; }


let finish_blind_auction (token : token_for_sale) (storage : storage) : result = 
    // get the auction data and remove it from storage
    let (data, storage) = 
        match Big_map.get_and_update token (None : blind_auction_data option) storage.tokens_on_blind_auction with 
        | (None, _) -> (failwith error_AUCTIONED_TOKEN_NOT_FOUND : blind_auction_data * storage)
        | (Some d, m) -> (d, {storage with tokens_on_blind_auction = m}) in 
    // check timeline
    if not (Tezos.now >= data.deadline + data.private_unlock_pd) 
        then (failwith error_AUCTION_NOT_OVER : result) else
    if Tezos.sender <> data.leader && Tezos.sender <> token.owner then (failwith error_PERMISSIONS_DENIED : result) else
    // transfer the XTZ to the token owner 
    let redeem = to_redeem token.owner (XTZ(data.leading_bid)) storage.redeem in 
    // transfer the tokens to the leader 
    let redeem = 
        let tokens_to_redeem = { token_address = token.token_address ; token_id = token.token_id ; qty = token.qty ; } in 
        to_redeem data.leader (Tokens(tokens_to_redeem)) storage.redeem in 
    // finish 
    ([] : operation list),
    { storage with
        redeem = redeem ; }


let blind_auction (param : blind_auction) (storage : storage) : result = 
    match param with 
    | InitiateBlindAuction p ->
        initiate_blind_auction p storage
    | BidOnBlindAuction p ->
        bid_on_blind_auction p storage 
    | UncoverBid p -> // a bidder uncovers their own bid
        uncover_bid p storage
    | RemoveBid p -> 
        remove_bid p storage 
    | FinishBlindAuction p ->
        finish_blind_auction p storage 


(*** **
 Offer Entrypoint Functions 
 *** **) 
let make_offer (token : token_for_sale) (storage : storage) : result = 
    // make sure the token is approved
    if not Big_map.mem { token_address = token.token_address ; token_id = token.token_id ; } storage.approved_tokens then (failwith error_TOKEN_NOT_APPROVED : result) else
    if Tezos.amount / 1mutez = 0n then (failwith error_OFFER_MUST_BE_NONZERO : result) else
    // the offer-maker sends their offer in the txn
    let quote = (Tezos.amount / 1mutez) in 
    let offering_party = Tezos.sender in 
    // collect data
    let token_offer : token_offer = {
        owner = token.owner ;
        token_address = token.token_address ; 
        token_id = token.token_id ;
        qty = token.qty ;
        offering_party = offering_party ; } in
    let data : offer_data = {
        quote = quote ; } in
    // update offers in storage
    let offers =
        match (Big_map.find_opt token_offer storage.offers : offer_data option) with 
        | Some _ -> (failwith error_OFFER_ALREADY_MADE : (token_offer, offer_data) big_map)
        | None -> Big_map.update token_offer (Some data) storage.offers in
    // output
    ([] : operation list), 
    { storage with offers = offers ; }

let retract_offer (token : token_for_sale) (storage : storage) : result = 
    // the offer-maker's data
    let token_offer : token_offer = {
        owner = token.owner ;
        token_address = token.token_address ; 
        token_id = token.token_id ;
        qty = token.qty ;
        offering_party = Tezos.sender ; } in
    // if no offer exists, nothing gets transferred 
    let (quote, new_offers) : nat * (token_offer, offer_data) big_map = 
        match (Big_map.get_and_update token_offer (None : offer_data option) storage.offers : offer_data option * (token_offer, offer_data) big_map) with
        | (None, o) -> (0n, o)
        | (Some q, o) -> (q.quote, o) in 
    // return the offering party's funds
    let entrypoint_return : unit contract =
        match (Tezos.get_contract_opt Tezos.sender : unit contract option) with 
        | None -> (failwith error_INVALID_ADDRESS : unit contract)
        | Some c -> c in 
    let op_return = Tezos.transaction () (quote * 1mutez) entrypoint_return in 
    // output
    [ op_return ; ],
    { storage with offers = new_offers ; }


// Permissions: the controller of the tokens on offer can accept an offer. 
//   this is regulated by the %transfer entrypoint
let accept_offer (token, data : token_offer * offer_data) (storage : storage) : result = 
    // make sure offer is as expected to prevent frontrunning attacks
    let (offer, offers) : offer_data * (token_offer, offer_data) big_map =
        match (Big_map.get_and_update token (None : offer_data option) storage.offers : offer_data option * (token_offer, offer_data) big_map) with
        | (None, _) -> (failwith error_NO_OFFER_FOUND : offer_data * (token_offer, offer_data) big_map)
        | (Some o, n) -> (o, n) in 
    if offer.quote <> data.quote then (failwith error_NO_OFFER_FOUND : result) else
    // transfer the tokens to the offering party
    let buyer = token.offering_party in 
    let txndata_send_tokens = {
        from_ = token.owner ; 
        txs = [ { to_ = buyer ; token_id = token.token_id ; amount = token.qty ; } ; ] ; } in 
    let entrypoint_send_tokens =
        match (Tezos.get_entrypoint_opt "%transfer" token.token_address : transfer list contract option) with 
        | None -> (failwith error_NO_TOKEN_CONTRACT_FOUND : transfer list contract)
        | Some e -> e in 
    let op_send_tokens = 
        Tezos.transaction [txndata_send_tokens] 0tez entrypoint_send_tokens in 
    // transfer the XTZ of the offer to the owner 
    let entrypoint_send_xtz : unit contract = 
        match (Tezos.get_contract_opt token.owner : unit contract option) with 
        | None -> (failwith error_INVALID_ADDRESS : unit contract)
        | Some c -> c in 
    let op_send_xtz = Tezos.transaction () (offer.quote * 1mutez) entrypoint_send_xtz in 
    // output
    [ op_send_tokens ; op_send_xtz ; ],
    { storage with offers = offers ; }

let offer (param : offer) (storage : storage) : result = 
    match param with 
    | MakeOffer p ->
        make_offer p storage
    | RetractOffer p ->
        retract_offer p storage
    | AcceptOffer p ->
        accept_offer p storage


(*** ** 
 Redeem Entrypoint Function
 *** **)

let rec redeem_assets (send_to, list_to_redeem, acc : address * (redeemable list) * (operation list)) : operation list = 
    match list_to_redeem with 
    | [] -> acc 
    | hd :: tl -> (
        match hd with 
        | Tokens t -> 
            // transfer tokens to send_to
            let txndata_send_tokens = {
                from_ = Tezos.self_address ; 
                txs = [ { to_ = send_to ; token_id = t.token_id ; amount = t.qty ; } ; ] ; } in 
            let entrypoint_send_tokens =
                match (Tezos.get_entrypoint_opt "%transfer" t.token_address : transfer list contract option) with 
                | None -> (failwith error_NO_TOKEN_CONTRACT_FOUND : transfer list contract)
                | Some e -> e in 
            let acc = (Tezos.transaction [txndata_send_tokens] 0tez entrypoint_send_tokens) :: acc in 
            redeem_assets(send_to, tl, acc)
        | XTZ amt -> 
            // check that amt > 0 
            if amt = 0n then redeem_assets(send_to, tl, acc) else 
            // transfer amt worth of XTZ to this address 
            let entrypoint_transfer = match (Tezos.get_contract_opt send_to : unit contract option) with
            | None -> (failwith error_INVALID_ADDRESS : unit contract)
            | Some c -> c in 
            let acc = (Tezos.transaction () (amt * 1mutez) entrypoint_transfer) :: acc in 
            redeem_assets(send_to, tl, acc))


let redeem (_ : unit) (storage : storage) : result = 
    let send_to = Tezos.sender in 
    // fetch their redeemable funds, make operations to send them, and send them; remove the redeemed assets from storage 
    let (list_to_redeem, redeem) = 
        match Big_map.get_and_update send_to (None : redeemable list option) storage.redeem with 
        | (None, rdm) -> ( ([] : redeemable list), rdm)
        | (Some l, rdm) -> (l, rdm) in
    let ops = redeem_assets (send_to, list_to_redeem, ([] : operation list)) in 
    ops, {storage with redeem = redeem ;}


(*** ** 
 ApproveTokens Entrypoint Functions 
 *** **)
let rec approve_tokens (param, storage : approve_tokens * storage) : result = 
    if Tezos.sender <> storage.carbon_contract then (failwith error_PERMISSIONS_DENIED : result) else 
    match param with 
    | [] -> (([] : operation list), storage)
    | hd :: tl ->
        let (token, add_or_remove) = hd in 
        let approved_tokens : (token, unit) big_map = 
            Big_map.update token add_or_remove storage.approved_tokens in
        approve_tokens (tl, {storage with approved_tokens = approved_tokens ;})


(* =============================================================================
 * Main
 * ============================================================================= *)

let main (entrypoint, storage : entrypoint * storage) = 
    match entrypoint with 
    // a seller posts their tokens for sale at a given price
    | ForSale param -> 
        for_sale param storage
    // a seller auctions off their tokens
    | Auction param -> 
        auction param storage
    // a seller auctions off their tokens in a sealed-bid auction
    | BlindAuction param -> 
        blind_auction param storage
    // a buyer makes an offer for some tokens
    | Offer param -> 
        offer param storage
    // redeem tokens or tez that are yours from an auction
    | Redeem param -> 
        redeem param storage
    // update which tokens are allowed to trade on this marketplace
    | ApproveTokens param -> 
        approve_tokens (param, storage)