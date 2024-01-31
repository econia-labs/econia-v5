module econia::core {

    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::object::{Object, ObjectGroup};
    use aptos_framework::table_with_length::{Self, TableWithLength};

    #[test_only]
    use aptos_framework::account;
    #[test_only]
    use econia::test_assets;

    const GENESIS_MARKET_REGISTRATION_FEE: u64 = 100000000;

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
        markets: TableWithLength<u64, MarketInfo>,
        utility_asset_metadata: Object<Metadata>,
        market_registration_fee: u64,
    }

    /// Stored under each user's account.
    struct MarketAccounts has key {
        map: TableWithLength<u64, MarketAccountInfo>
    }

    fun init_module_internal(
        econia: &signer,
        utility_asset_metadata: Object<Metadata>
    ) {
        move_to(econia, Registry {
            markets: table_with_length::new(),
            utility_asset_metadata,
            market_registration_fee: GENESIS_MARKET_REGISTRATION_FEE,
        });
    }

    #[test_only]
    public fun init_module_test() {
        let (_, quote_asset) = test_assets::get_metadata();
        init_module_internal(&account::create_signer_for_test(@econia), quote_asset);
    }

}