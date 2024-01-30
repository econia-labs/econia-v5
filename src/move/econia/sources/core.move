module econia::core {

    use aptos_framework::fungible_asset::{Self, BurnRef, MintRef, Metadata};
    use aptos_framework::object::{Self, ExtendRef, Object, ObjectGroup};
    use aptos_framework::table_with_length::{TableWithLength};

    #[resource_group_member(group = ObjectGroup)]
    struct Market has key {
        id: u64,
        lot_size: u64,
        tick_size: u64,
        min_post_size: u64,
        pool_fee_bps: u16,
        taker_fee_bps: u16,
    }

    #[resource_group_member(group = ObjectGroup)]
    struct MarketAccount has key {
        market: Object<Market>,
        market_id: u64,
    }

    struct MarketAccountInfo has store {
        market: Object<Market>,
        market_id: u64,
        user: address,
    }

    // For duplicate checks.
    struct PairInfo has store {}

    struct MarketInfo has store {
        id: u64,
        market: Object<Market>,
        lot_size: u64,
        tick_size: u64,
        min_post_size: u64,
        pool_fee_bps: u16,
        taker_fee_bps: u16,
    }

    /// Stored under Econia account.
    struct Registry has key {
        markets: TableWithLength<u64, MarketInfo>
    }

    /// Stored under each user's account.
    struct MarketAccounts has key {
        map: TableWithLength<u64, MarketAccountInfo>
    }

}