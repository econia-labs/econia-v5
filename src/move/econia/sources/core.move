module econia::core {

    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::object::{Self, Object, ObjectGroup};
    use aptos_framework::table::{Self, Table};
    use aptos_framework::table_with_length::{Self, TableWithLength};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::smart_table::{Self, SmartTable};
    use std::signer;
    use std::vector;

    #[test_only]
    use aptos_framework::account;
    #[test_only]
    use aptos_framework::aptos_coin;
    #[test_only]
    use econia::test_assets;

    const GENESIS_UTILITY_ASSET_METADATA_ADDRESS: address = @aptos_framework;
    const GENESIS_MARKET_REGISTRATION_FEE: u64 = 100_000_000;
    const GENESIS_ORACLE_FEE: u64 = 1_000;

    const GENESIS_DEFAULT_POOL_FEE_RATE_BPS: u8 = 30;
    const GENESIS_DEFAULT_MAX_PRICE_SIG_FIGS: u8 = 4;
    const GENESIS_DEFAULT_MAX_POSTED_ORDERS_PER_SIDE: u32 = 1000;
    const GENESIS_DEFAULT_EVICTION_TREE_HEIGHT: u8 = 5;
    const GENESIS_DEFAULT_EVICTION_PRICE_DIVISOR_ASK: u128 = 100_000_000_000_000_000_000;
    const GENESIS_DEFAULT_EVICTION_PRICE_DIVISOR_BID: u128 = 100_000_000_000_000_000_000;
    const GENESIS_DEFAULT_EVICTION_LIQUIDITY_DIVISOR: u128 = 1_000_000_000_000_000_000_000_000;

    const FEE_RATE_NULL: u8 = 0;

    /// Registrant's utility asset primary fungible store balance is below market registration fee.
    const E_NOT_ENOUGH_UTILITY_ASSET_TO_REGISTER_MARKET: u64 = 0;
    /// A market is already registered for the given trading pair.
    const E_TRADING_PAIR_ALREADY_REGISTERED: u64 = 1;
    /// Signer is not Econia.
    const E_NOT_ECONIA: u64 = 2;
    /// Market ID is not valid.
    const E_INVALID_MARKET_ID: u64 = 3;

    #[resource_group_member(group = ObjectGroup)]
    struct Market has key {
        market_id: u64,
        trading_pair: TradingPair,
        market_parameters: MarketParameters,
    }

    struct MarketMetadata has copy, drop, store {
        market_id: u64,
        market_object: Object<Market>,
        trading_pair: TradingPair,
        market_parameters: MarketParameters,
    }

    struct MarketParameters has copy, drop, store {
        pool_fee_rate_bps: u8,
        taker_fee_rate_bps: u8,
        max_price_sig_figs: u8,
        eviction_tree_height: u8,
        eviction_price_divisor_ask: u128,
        eviction_price_divisor_bid: u128,
        eviction_liquidity_divisor: u128,
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

    struct MarketAccounts has key {
        market_accounts: SmartTable<u64, MarketAccountMetadata>,
    }

    struct Null has drop, store {}

    struct Registry has key {
        markets: TableWithLength<u64, MarketMetadata>,
        trading_pair_market_ids: Table<TradingPair, u64>,
        recognized_market_ids: SmartTable<u64, Null>,
        utility_asset_metadata: Object<Metadata>,
        market_registration_fee: u64,
        oracle_fee: u64,
        default_market_parameters: MarketParameters,
    }

    struct TradingPair has copy, drop, store {
        base_metadata: Object<Metadata>,
        quote_metadata: Object<Metadata>,
    }

    public entry fun register_market(
        registrant: &signer,
        base_metadata: Object<Metadata>,
        quote_metadata: Object<Metadata>,
    ) acquires Registry {
        let registry_ref_mut = borrow_registry_mut();
        let utility_asset_metadata = registry_ref_mut.utility_asset_metadata;
        let registrant_balance = primary_fungible_store::balance(
            signer::address_of(registrant),
            utility_asset_metadata
        );
        let market_registration_fee = registry_ref_mut.market_registration_fee;
        assert!(
            registrant_balance >= market_registration_fee,
            E_NOT_ENOUGH_UTILITY_ASSET_TO_REGISTER_MARKET,
        );
        primary_fungible_store::transfer(
            registrant,
            utility_asset_metadata,
            @econia,
            market_registration_fee,
        );
        let trading_pair = TradingPair { base_metadata, quote_metadata };
        let trading_pair_market_ids_ref_mut = &mut registry_ref_mut.trading_pair_market_ids;
        assert!(
            !table::contains(trading_pair_market_ids_ref_mut, trading_pair),
            E_TRADING_PAIR_ALREADY_REGISTERED,
        );
        let markets_ref_mut = &mut registry_ref_mut.markets;
        let market_id = table_with_length::length(markets_ref_mut) + 1;
        let constructor_ref = object::create_object(@econia);
        let market_parameters = registry_ref_mut.default_market_parameters;
        let market_signer = object::generate_signer(&constructor_ref);
        move_to(&market_signer, Market {
            market_id,
            trading_pair,
            market_parameters,
        });
        let market_metadata = MarketMetadata {
            market_id,
            market_object: object::object_from_constructor_ref(&constructor_ref),
            trading_pair,
            market_parameters,
        };
        table_with_length::add(markets_ref_mut, market_id, market_metadata);
        table::add(trading_pair_market_ids_ref_mut, trading_pair, market_id);
    }

    public entry fun update_recognized_markets(
        econia: &signer,
        market_ids_to_recognize: vector<u64>,
        market_ids_to_unrecognize: vector<u64>,
    ) acquires Registry {
        assert_signer_is_econia(econia);
        let registry_ref_mut = borrow_registry_mut();
        let recognized_market_ids_ref_mut = &mut registry_ref_mut.recognized_market_ids;
        let n_markets = table_with_length::length(&registry_ref_mut.markets);
        vector::for_each_ref(&market_ids_to_recognize, |market_id_ref| {
            if (!smart_table::contains(recognized_market_ids_ref_mut, *market_id_ref)) {
                assert!(*market_id_ref <= n_markets, E_INVALID_MARKET_ID);
                smart_table::add(recognized_market_ids_ref_mut, *market_id_ref, Null {});
            }
        });
        vector::for_each_ref(&market_ids_to_unrecognize, |market_id_ref| {
            if (smart_table::contains(recognized_market_ids_ref_mut, *market_id_ref)) {
                smart_table::remove(recognized_market_ids_ref_mut, *market_id_ref);
            }
        });
    }

    fun init_module(econia: &signer) {
        move_to(econia, Registry {
            markets: table_with_length::new(),
            trading_pair_market_ids: table::new(),
            recognized_market_ids: smart_table::new(),
            utility_asset_metadata:
                object::address_to_object<Metadata>(GENESIS_UTILITY_ASSET_METADATA_ADDRESS),
            market_registration_fee: GENESIS_MARKET_REGISTRATION_FEE,
            oracle_fee: GENESIS_ORACLE_FEE,
            default_market_parameters: MarketParameters {
                pool_fee_rate_bps: GENESIS_DEFAULT_POOL_FEE_RATE_BPS,
                taker_fee_rate_bps: FEE_RATE_NULL,
                max_price_sig_figs: GENESIS_DEFAULT_MAX_PRICE_SIG_FIGS,
                eviction_tree_height: GENESIS_DEFAULT_EVICTION_TREE_HEIGHT,
                eviction_price_divisor_ask: GENESIS_DEFAULT_EVICTION_PRICE_DIVISOR_ASK,
                eviction_price_divisor_bid: GENESIS_DEFAULT_EVICTION_PRICE_DIVISOR_BID,
                eviction_liquidity_divisor: GENESIS_DEFAULT_EVICTION_LIQUIDITY_DIVISOR,
            },
        });
    }

    fun assert_signer_is_econia(account: &signer) {
        assert!(signer::address_of(account) == @econia, E_NOT_ECONIA);
    }

    inline fun borrow_registry(): &Registry { borrow_global<Registry>(@econia) }

    inline fun borrow_registry_mut(): &mut Registry { borrow_global_mut<Registry>(@econia) }

    #[test_only]
    const MARKET_REGISTRANT_FOR_TEST: address = @0xace;

    #[test_only]
    public fun ensure_module_initialized_for_test() {
        aptos_coin::ensure_initialized_with_fa_metadata_for_test();
        if (!exists<Registry>(@econia)) init_module(&get_signer(@econia));
    }

    #[test_only]
    public fun get_test_trading_pair(): TradingPair {
        let (base_metadata, quote_metadata) = test_assets::get_metadata();
        TradingPair { base_metadata, quote_metadata }
    }

    #[test_only]
    public fun get_test_trading_pair_flipped(): TradingPair {
        let (base_metadata, quote_metadata) = test_assets::get_metadata();
        TradingPair { base_metadata: quote_metadata, quote_metadata: base_metadata }
    }

    #[test_only]
    public fun mint_fa_apt_to_market_registrant() {
        aptos_coin::mint_fa_to_primary_fungible_store_for_test(
            MARKET_REGISTRANT_FOR_TEST,
            GENESIS_MARKET_REGISTRATION_FEE
        );
    }

    #[test_only]
    public fun ensure_market_initialized_for_test() acquires Registry {
        ensure_module_initialized_for_test();
        let trading_pair = get_test_trading_pair();
        let registry_ref = borrow_global<Registry>(@econia);
        if (table::contains(&registry_ref.trading_pair_market_ids, trading_pair)) return;
        mint_fa_apt_to_market_registrant();
        let registrant = get_signer(MARKET_REGISTRANT_FOR_TEST);
        register_market(&registrant, trading_pair.base_metadata, trading_pair.quote_metadata);
    }

    #[test_only]
    public fun ensure_markets_initialized_for_test() acquires Registry {
        ensure_market_initialized_for_test();
        let trading_pair_flipped = get_test_trading_pair_flipped();
        let registry_ref = borrow_global<Registry>(@econia);
        if (table::contains(&registry_ref.trading_pair_market_ids, trading_pair_flipped)) return;
        mint_fa_apt_to_market_registrant();
        register_market(
            &get_signer(MARKET_REGISTRANT_FOR_TEST),
            trading_pair_flipped.base_metadata,
            trading_pair_flipped.quote_metadata
        );
    }

    #[test_only]
    public fun get_signer(addr: address): signer { account::create_signer_for_test(addr) }

    #[test, expected_failure(abort_code = E_NOT_ECONIA)]
    fun test_assert_signer_is_econia_not_econia() {
        assert_signer_is_econia(&get_signer(@0x0));
    }

    #[test]
    fun test_genesis_values() acquires Registry {
        ensure_module_initialized_for_test();
        let registry_ref = borrow_global<Registry>(@econia);
        assert!(registry_ref.market_registration_fee == GENESIS_MARKET_REGISTRATION_FEE, 0);
        assert!(registry_ref.oracle_fee == GENESIS_ORACLE_FEE, 0);
        let params = registry_ref.default_market_parameters;
        assert!(params.pool_fee_rate_bps == GENESIS_DEFAULT_POOL_FEE_RATE_BPS, 0);
        assert!(params.taker_fee_rate_bps == FEE_RATE_NULL, 0);
        assert!(params.max_price_sig_figs == GENESIS_DEFAULT_MAX_PRICE_SIG_FIGS, 0);
        assert!(params.eviction_tree_height == GENESIS_DEFAULT_EVICTION_TREE_HEIGHT, 0);
        assert!(params.eviction_price_divisor_ask == GENESIS_DEFAULT_EVICTION_PRICE_DIVISOR_ASK, 0);
        assert!(params.eviction_price_divisor_bid == GENESIS_DEFAULT_EVICTION_PRICE_DIVISOR_BID, 0);
        assert!(params.eviction_liquidity_divisor == GENESIS_DEFAULT_EVICTION_LIQUIDITY_DIVISOR, 0);
    }

    #[test]
    fun test_register_market() acquires Market, Registry {
        ensure_markets_initialized_for_test();
        let registry_ref = borrow_global<Registry>(@econia);
        let trading_pair_market_ids_ref = &registry_ref.trading_pair_market_ids;
        let trading_pair = get_test_trading_pair();
        let trading_pair_flipped = get_test_trading_pair_flipped();
        assert!(*table::borrow(trading_pair_market_ids_ref, trading_pair) == 1, 0);
        assert!(*table::borrow(trading_pair_market_ids_ref, trading_pair_flipped) == 2, 0);
        let default_market_parameters = registry_ref.default_market_parameters;
        let market_metadata = *table_with_length::borrow(&registry_ref.markets, 1);
        assert!(market_metadata.market_id == 1, 0);
        assert!(market_metadata.trading_pair == trading_pair, 0);
        assert!(market_metadata.market_parameters == default_market_parameters, 0);
        let market_address = object::object_address(&market_metadata.market_object);
        let market_ref = borrow_global<Market>(market_address);
        assert!(market_ref.market_id == 1, 0);
        assert!(market_ref.trading_pair == trading_pair, 0);
        assert!(market_ref.market_parameters == default_market_parameters, 0);
        market_metadata = *table_with_length::borrow(&registry_ref.markets, 2);
        assert!(market_metadata.market_id == 2, 0);
        assert!(market_metadata.trading_pair == trading_pair_flipped, 0);
        assert!(market_metadata.market_parameters == default_market_parameters, 0);
        market_address = object::object_address(&market_metadata.market_object);
        market_ref = borrow_global<Market>(market_address);
        assert!(market_ref.market_id == 2, 0);
        assert!(market_ref.trading_pair == trading_pair_flipped, 0);
        assert!(market_ref.market_parameters == default_market_parameters, 0);
    }

    #[test, expected_failure(abort_code = E_NOT_ENOUGH_UTILITY_ASSET_TO_REGISTER_MARKET)]
    fun test_register_market_not_enough_utility_asset() acquires Registry {
        ensure_market_initialized_for_test();
        let trading_pair = get_test_trading_pair();
        let registrant = get_signer(MARKET_REGISTRANT_FOR_TEST);
        register_market(&registrant, trading_pair.base_metadata, trading_pair.quote_metadata);
    }

    #[test, expected_failure(abort_code = E_TRADING_PAIR_ALREADY_REGISTERED)]
    fun test_register_market_trading_pair_already_registered() acquires Registry {
        ensure_market_initialized_for_test();
        let trading_pair = get_test_trading_pair();
        mint_fa_apt_to_market_registrant();
        let registrant = get_signer(MARKET_REGISTRANT_FOR_TEST);
        register_market(&registrant, trading_pair.base_metadata, trading_pair.quote_metadata);
    }

    #[test]
    fun test_update_recognized_markets() acquires Registry {
        ensure_markets_initialized_for_test();
        let registry_ref = borrow_registry();
        assert!(!smart_table::contains(&registry_ref.recognized_market_ids, 1), 0);
        assert!(!smart_table::contains(&registry_ref.recognized_market_ids, 2), 0);
        update_recognized_markets(&get_signer(@econia), vector[2], vector[]);
        update_recognized_markets(&get_signer(@econia), vector[1, 2], vector[]);
        let registry_ref = borrow_registry();
        assert!(smart_table::contains(&registry_ref.recognized_market_ids, 1), 0);
        assert!(smart_table::contains(&registry_ref.recognized_market_ids, 2), 0);
        update_recognized_markets(&get_signer(@econia), vector[], vector[1]);
        update_recognized_markets(&get_signer(@econia), vector[], vector[1, 2]);
        let registry_ref = borrow_registry();
        assert!(!smart_table::contains(&registry_ref.recognized_market_ids, 1), 0);
        assert!(!smart_table::contains(&registry_ref.recognized_market_ids, 2), 0);
    }

    #[test, expected_failure(abort_code = E_INVALID_MARKET_ID)]
    fun test_update_recognized_markets_invalid_market_id() acquires Registry {
        ensure_module_initialized_for_test();
        update_recognized_markets(&get_signer(@econia), vector[1], vector[]);
    }

}
