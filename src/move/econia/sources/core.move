module econia::core {

    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::object::{Self, Object, ObjectGroup};
    use aptos_framework::table::{Self, Table};
    use aptos_framework::table_with_length::{Self, TableWithLength};
    use aptos_framework::primary_fungible_store;
    use aptos_std::smart_vector::{SmartVector};
    use std::signer;

    #[test_only]
    use aptos_framework::account;
    #[test_only]
    use econia::test_assets;

    const GENESIS_MARKET_REGISTRATION_FEE: u64 = 100000000;
    const GENESIS_DEFAULT_POOL_FEE_BPS: u16 = 20;
    const GENESIS_DEFAULT_TAKER_FEE_BPS: u16 = 0;

    /// Registrant's utility asset primary fungible store balance is below market registration fee.
    const E_NOT_ENOUGH_UTILITY_ASSET_TO_REGISTER_MARKET: u64 = 0;
    /// The given trading pair already exists.
    const E_PAIR_ALREADY_REGISTERED: u64 = 1;

    #[resource_group_member(group = ObjectGroup)]
    struct Market has key {
        market_id: u64,
        trading_pair: TradingPair,
        lot_size: u64,
        tick_size: u64,
        min_post_size: u64,
        pool_fee_bps: u16,
        taker_fee_bps: u16,
    }

    struct MarketMetadata has copy, store {
        market_id: u64,
        market_object: Object<Market>,
        trading_pair: TradingPair,
        lot_size: u64,
        tick_size: u64,
        min_post_size: u64,
        pool_fee_bps: u16,
        taker_fee_bps: u16,
    }

    #[resource_group_member(group = ObjectGroup)]
    struct MarketAccount has key {
        market_id: u64,
        market_object: Object<Market>,
        user: address,
    }

    struct MarketAccountMetadata has store {
        market_id: u64,
        market_object: Object<Market>,
        user: address,
        market_account_object: Object<MarketAccount>,
    }

    struct MarketAccountsManifest has key {
        market_ids: SmartVector<u64>,
        market_accounts: Table<u64, MarketAccountMetadata>,
    }

    struct Registry has key {
        markets: TableWithLength<u64, MarketMetadata>,
        pairs: Table<SizedPair, u64>,
        recognized_markets: Table<TradingPair, u64>,
        utility_asset_metadata: Object<Metadata>,
        market_registration_fee: u64,
        default_pool_fee_bps: u16,
        default_taker_fee_bps: u16,
    }

    struct SizedPair has copy, drop, store {
        trading_pair: TradingPair,
        lot_size: u64,
        tick_size: u64,
        min_post_size: u64,
    }

    struct TradingPair has copy, drop, store {
        base_metadata: Object<Metadata>,
        quote_metadata: Object<Metadata>,
    }

    public entry fun register_market(
        registrant: &signer,
        base_metadata: Object<Metadata>,
        quote_metadata: Object<Metadata>,
        lot_size: u64,
        tick_size: u64,
        min_post_size: u64,
    ) acquires Registry {
        let registry_ref_mut = borrow_global_mut<Registry>(@econia);
        let utility_asset_metadata = registry_ref_mut.utility_asset_metadata;
        let registrant_balance = primary_fungible_store::balance(
            signer::address_of(registrant),
            utility_asset_metadata
        );
        let market_registration_fee = registry_ref_mut.market_registration_fee;
        assert!(
            registrant_balance >= market_registration_fee,
            E_NOT_ENOUGH_UTILITY_ASSET_TO_REGISTER_MARKET
        );
        primary_fungible_store::transfer(
            registrant,
            utility_asset_metadata,
            @econia,
            market_registration_fee,
        );
        let trading_pair = TradingPair { base_metadata, quote_metadata };
        let sized_pair_info = SizedPair {
            trading_pair,
            lot_size,
            tick_size,
            min_post_size,
        };
        let pairs_map_ref_mut = &mut registry_ref_mut.pairs;
        assert!(!table::contains(pairs_map_ref_mut, sized_pair_info), E_PAIR_ALREADY_REGISTERED);
        let markets_map_ref_mut = &mut registry_ref_mut.markets;
        let market_id = table_with_length::length(markets_map_ref_mut);
        let constructor_ref = object::create_object(@econia);
        let market_object = object::object_from_constructor_ref(&constructor_ref);
        let pool_fee_bps = registry_ref_mut.default_pool_fee_bps;
        let taker_fee_bps = registry_ref_mut.default_taker_fee_bps;
        let market_metadata = MarketMetadata {
            market_id,
            market_object,
            trading_pair,
            lot_size,
            tick_size,
            min_post_size,
            pool_fee_bps,
            taker_fee_bps,
        };
        let market_signer = object::generate_signer(&constructor_ref);
        move_to(&market_signer, Market {
            market_id,
            trading_pair,
            lot_size,
            tick_size,
            min_post_size,
            pool_fee_bps,
            taker_fee_bps,
        });
        table_with_length::add(markets_map_ref_mut, market_id, market_metadata);
        table::add(pairs_map_ref_mut, sized_pair_info, market_id);
    }

    fun init_module_internal(
        econia: &signer,
        utility_asset_metadata: Object<Metadata>
    ) {
        move_to(econia, Registry {
            markets: table_with_length::new(),
            pairs: table::new(),
            recognized_markets: table::new(),
            utility_asset_metadata,
            market_registration_fee: GENESIS_MARKET_REGISTRATION_FEE,
            default_pool_fee_bps: GENESIS_DEFAULT_POOL_FEE_BPS,
            default_taker_fee_bps: GENESIS_DEFAULT_TAKER_FEE_BPS,
        });
    }

    #[test_only]
    public fun init_module_test() {
        let (_, quote_asset) = test_assets::get_metadata();
        init_module_internal(&account::create_signer_for_test(@econia), quote_asset);
    }

}