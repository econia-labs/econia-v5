// # cspell:words ungated, unrecognize
module econia::core {

    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::object::{Self, ConstructorRef, ExtendRef, Object, ObjectGroup};
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
    const GENESIS_DEFAULT_TAKER_FEE_RATE_BPS: u8 = 0;
    const GENESIS_DEFAULT_MAX_PRICE_SIG_FIGS: u8 = 4;
    const GENESIS_DEFAULT_EVICTION_TREE_HEIGHT: u8 = 5;
    const GENESIS_DEFAULT_EVICTION_PRICE_DIVISOR_ASK: u128 = 100_000_000_000_000_000_000;
    const GENESIS_DEFAULT_EVICTION_PRICE_DIVISOR_BID: u128 = 100_000_000_000_000_000_000;
    const GENESIS_DEFAULT_EVICTION_LIQUIDITY_DIVISOR: u128 = 1_000_000_000_000_000_000_000_000;

    /// Registrant's utility asset primary fungible store balance is below market registration fee.
    const E_NOT_ENOUGH_UTILITY_ASSET_TO_REGISTER_MARKET: u64 = 0;
    /// Signer is not Econia.
    const E_NOT_ECONIA: u64 = 1;
    /// Market ID is not valid.
    const E_INVALID_MARKET_ID: u64 = 2;
    /// An option represented as a vector has more than 1 element.
    const E_OPTION_VECTOR_TOO_LONG: u64 = 3;
    /// Base and quote metadata are identical.
    const E_BASE_QUOTE_METADATA_SAME: u64 = 4;

    #[resource_group_member(group = ObjectGroup)]
    struct Market has key {
        market_id: u64,
        trading_pair: TradingPair,
        market_parameters: MarketParameters,
        extend_ref: ExtendRef,
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
        trading_pair: TradingPair,
        market_object: Object<Market>,
        user: address,
        extend_ref: ExtendRef,
        base_available: u64,
        base_total: u64,
        quote_available: u64,
        quote_total: u64,
    }

    struct MarketAccountMetadata has copy, drop, store {
        market_id: u64,
        trading_pair: TradingPair,
        market_object: Object<Market>,
        user: address,
        market_account_object: Object<MarketAccount>,
    }

    struct MarketAccounts has key {
        map: SmartTable<TradingPair, MarketAccountMetadata>,
    }

    struct Null has drop, store {}

    struct RegistryParameters has copy, drop, store {
        utility_asset_metadata: Object<Metadata>,
        market_registration_fee: u64,
        oracle_fee: u64,
    }

    struct Registry has key {
        markets: TableWithLength<u64, MarketMetadata>,
        trading_pair_market_ids: Table<TradingPair, u64>,
        recognized_market_ids: SmartTable<u64, Null>,
        registry_parameters: RegistryParameters,
        default_market_parameters: MarketParameters,
    }

    struct TradingPair has copy, drop, store {
        base_metadata: Object<Metadata>,
        quote_metadata: Object<Metadata>,
    }

    public entry fun ensure_market_registered(
        registrant: &signer,
        base_metadata: Object<Metadata>,
        quote_metadata: Object<Metadata>,
    ) acquires Registry {
        let registry_ref_mut = borrow_registry_mut();
        let trading_pair = TradingPair { base_metadata, quote_metadata };
        let trading_pair_market_ids_ref_mut = &mut registry_ref_mut.trading_pair_market_ids;
        if (table::contains(trading_pair_market_ids_ref_mut, trading_pair)) return;
        assert!(base_metadata != quote_metadata, E_BASE_QUOTE_METADATA_SAME);
        let utility_asset_metadata = registry_ref_mut.registry_parameters.utility_asset_metadata;
        let market_registration_fee = registry_ref_mut.registry_parameters.market_registration_fee;
        let registrant_balance = primary_fungible_store::balance(
            signer::address_of(registrant),
            utility_asset_metadata
        );
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
        let markets_ref_mut = &mut registry_ref_mut.markets;
        let market_id = table_with_length::length(markets_ref_mut) + 1;
        let (constructor_ref, extend_ref) = create_nontransferrable_sticky_object(@econia);
        let market_parameters = registry_ref_mut.default_market_parameters;
        let market_signer = object::generate_signer(&constructor_ref);
        move_to(&market_signer, Market {
            market_id,
            trading_pair,
            market_parameters,
            extend_ref,
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

    public entry fun ensure_market_account_registered(
        user: &signer,
        base_metadata: Object<Metadata>,
        quote_metadata: Object<Metadata>,
    ) acquires MarketAccounts, Registry {
        let user_address = signer::address_of(user);
        if (!exists<MarketAccounts>(user_address)) {
            move_to(user, MarketAccounts { map: smart_table::new() });
        };
        let trading_pair = TradingPair { base_metadata, quote_metadata };
        let market_accounts_map_ref_mut = &mut borrow_global_mut<MarketAccounts>(user_address).map;
        if (smart_table::contains(market_accounts_map_ref_mut, trading_pair)) return;
        ensure_market_registered(user, base_metadata, quote_metadata);
        let registry_ref = borrow_registry();
        let trading_pair_market_ids_ref = &registry_ref.trading_pair_market_ids;
        let market_id = *table::borrow(trading_pair_market_ids_ref, trading_pair);
        let market_object =
            table_with_length::borrow(&registry_ref.markets, market_id).market_object;
        let (constructor_ref, extend_ref) = create_nontransferrable_sticky_object(user_address);
        move_to(&object::generate_signer(&constructor_ref), MarketAccount {
            market_id,
            trading_pair,
            market_object,
            user: user_address,
            extend_ref,
            base_available: 0,
            base_total: 0,
            quote_available: 0,
            quote_total: 0,
        });
        smart_table::add(
            market_accounts_map_ref_mut,
            trading_pair,
            MarketAccountMetadata {
                market_id,
                trading_pair,
                market_object,
                user: user_address,
                market_account_object: object::object_from_constructor_ref(&constructor_ref),
            }
        );
    }

    public entry fun update_market_parameters(
        econia: &signer,
        market_id_option: vector<u64>,
        pool_fee_rate_bps_option: vector<u8>,
        taker_fee_rate_bps_option: vector<u8>,
        max_price_sig_figs_option: vector<u8>,
        eviction_tree_height_option: vector<u8>,
        eviction_price_divisor_ask_option: vector<u128>,
        eviction_price_divisor_bid_option: vector<u128>,
        eviction_liquidity_divisor_option: vector<u128>,
    ) acquires Market, Registry {
        assert_signer_is_econia(econia);
        assert_option_vector_is_valid_length(&market_id_option);
        let updating_default_parameters = vector::is_empty(&market_id_option);
        let registry_ref_mut = borrow_registry_mut();
        let (market_parameters_ref_mut, market_address) = if (updating_default_parameters) {
            (&mut registry_ref_mut.default_market_parameters, @0x0)
        } else {
            let market_id = *vector::borrow(&market_id_option, 0);
            let markets_ref_mut = &mut registry_ref_mut.markets;
            let market_exists = table_with_length::contains(markets_ref_mut, market_id);
            assert!(market_exists, E_INVALID_MARKET_ID);
            let market_metadata_ref_mut = table_with_length::borrow_mut(markets_ref_mut, market_id);
            (
                &mut market_metadata_ref_mut.market_parameters,
                object::object_address(&market_metadata_ref_mut.market_object),
            )
        };
        set_value_via_option_vector(
            &mut market_parameters_ref_mut.pool_fee_rate_bps,
            &pool_fee_rate_bps_option,
        );
        set_value_via_option_vector(
            &mut market_parameters_ref_mut.taker_fee_rate_bps,
            &taker_fee_rate_bps_option,
        );
        set_value_via_option_vector(
            &mut market_parameters_ref_mut.max_price_sig_figs,
            &max_price_sig_figs_option,
        );
        set_value_via_option_vector(
            &mut market_parameters_ref_mut.eviction_tree_height,
            &eviction_tree_height_option,
        );
        set_value_via_option_vector(
            &mut market_parameters_ref_mut.eviction_price_divisor_ask,
            &eviction_price_divisor_ask_option,
        );
        set_value_via_option_vector(
            &mut market_parameters_ref_mut.eviction_price_divisor_bid,
            &eviction_price_divisor_bid_option,
        );
        set_value_via_option_vector(
            &mut market_parameters_ref_mut.eviction_liquidity_divisor,
            &eviction_liquidity_divisor_option,
        );
        if (!updating_default_parameters) {
            borrow_global_mut<Market>(market_address).market_parameters =
                *market_parameters_ref_mut;
        }
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

    public entry fun update_registry_parameters(
        econia: &signer,
        utility_asset_metadata_address_option: vector<address>,
        market_registration_fee_option: vector<u64>,
        oracle_fee_option: vector<u64>,
    ) acquires Registry {
        assert_signer_is_econia(econia);
        let registry_parameters_ref_mut = &mut borrow_registry_mut().registry_parameters;
        set_object_via_address_option_vector(
            &mut registry_parameters_ref_mut.utility_asset_metadata,
            &utility_asset_metadata_address_option,
        );
        set_value_via_option_vector(
            &mut registry_parameters_ref_mut.market_registration_fee,
            &market_registration_fee_option
        );
        set_value_via_option_vector(
            &mut registry_parameters_ref_mut.oracle_fee,
            &oracle_fee_option
        );
    }

    fun create_nontransferrable_sticky_object(owner: address): (ConstructorRef, ExtendRef) {
        let constructor_ref = object::create_sticky_object(owner);
        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        object::disable_ungated_transfer(&transfer_ref);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        (constructor_ref, extend_ref)
    }

    fun init_module(econia: &signer) {
        move_to(econia, Registry {
            markets: table_with_length::new(),
            trading_pair_market_ids: table::new(),
            recognized_market_ids: smart_table::new(),
            registry_parameters: RegistryParameters {
                utility_asset_metadata:
                    object::address_to_object<Metadata>(GENESIS_UTILITY_ASSET_METADATA_ADDRESS),
                market_registration_fee: GENESIS_MARKET_REGISTRATION_FEE,
                oracle_fee: GENESIS_ORACLE_FEE,
            },
            default_market_parameters: MarketParameters {
                pool_fee_rate_bps: GENESIS_DEFAULT_POOL_FEE_RATE_BPS,
                taker_fee_rate_bps: GENESIS_DEFAULT_TAKER_FEE_RATE_BPS,
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

    fun assert_option_vector_is_valid_length<T>(option_vector_ref: &vector<T>) {
        assert!(vector::length(option_vector_ref) <= 1, E_OPTION_VECTOR_TOO_LONG);
    }

    fun set_value_via_option_vector<T: copy + drop>(
        value_ref_mut: &mut T,
        option_vector_ref: &vector<T>
    ) {
        assert_option_vector_is_valid_length(option_vector_ref);
        if (!vector::is_empty(option_vector_ref)) {
            *value_ref_mut = *vector::borrow(option_vector_ref, 0);
        }
    }

    fun set_object_via_address_option_vector<T: key>(
        object_ref_mut: &mut Object<T>,
        address_option_vector_ref: &vector<address>
    ) {
        assert_option_vector_is_valid_length(address_option_vector_ref);
        if (!vector::is_empty(address_option_vector_ref)) {
            *object_ref_mut = object::address_to_object<T>(
                *vector::borrow(address_option_vector_ref, 0)
            );
        }
    }

    inline fun borrow_registry(): &Registry { borrow_global<Registry>(@econia) }

    inline fun borrow_registry_mut(): &mut Registry { borrow_global_mut<Registry>(@econia) }

    #[test_only]
    const MARKET_REGISTRANT_FOR_TEST: address = @0xace;
    #[test_only]
    const USER_FOR_TEST: address = @0xbee;

    #[test_only]
    public fun assert_market_parameters(
        market_parameters: MarketParameters,
        pool_fee_rate_bps: u8,
        taker_fee_rate_bps: u8,
        max_price_sig_figs: u8,
        eviction_tree_height: u8,
        eviction_price_divisor_ask: u128,
        eviction_price_divisor_bid: u128,
        eviction_liquidity_divisor: u128,
    ) {
        assert!(market_parameters.pool_fee_rate_bps == pool_fee_rate_bps, 0);
        assert!(market_parameters.taker_fee_rate_bps == taker_fee_rate_bps, 0);
        assert!(market_parameters.max_price_sig_figs == max_price_sig_figs, 0);
        assert!(market_parameters.eviction_tree_height == eviction_tree_height, 0);
        assert!(market_parameters.eviction_price_divisor_ask == eviction_price_divisor_ask, 0);
        assert!(market_parameters.eviction_price_divisor_bid == eviction_price_divisor_bid, 0);
        assert!(market_parameters.eviction_liquidity_divisor == eviction_liquidity_divisor, 0);
    }

    #[test_only]
    public fun assert_registry_parameters(
        registry_parameters: RegistryParameters,
        utility_asset_metadata_address: address,
        market_registration_fee: u64,
        oracle_fee: u64,
    ) {
        let utility_asset_metadata_address_to_check =
            object::object_address(&registry_parameters.utility_asset_metadata);
        assert!(utility_asset_metadata_address_to_check == utility_asset_metadata_address, 0);
        assert!(registry_parameters.market_registration_fee == market_registration_fee, 0);
        assert!(registry_parameters.oracle_fee == oracle_fee, 0);
    }

    #[test_only]
    public fun assert_market_account_fields(
        market_account_object: Object<MarketAccount>,
        market_id: u64,
        trading_pair: TradingPair,
        market_object: Object<Market>,
        user: address,
        base_available: u64,
        base_total: u64,
        quote_available: u64,
        quote_total: u64,
    ) acquires MarketAccount {
        let market_account_object_address = object::object_address(&market_account_object);
        let market_account_ref = borrow_global<MarketAccount>(market_account_object_address);
        assert!(market_account_ref.market_id == market_id, 0);
        assert!(market_account_ref.trading_pair == trading_pair, 0);
        assert!(market_account_ref.market_object == market_object, 0);
        assert!(market_account_ref.user == user, 0);
        let extend_ref_address = object::address_from_extend_ref(&market_account_ref.extend_ref);
        assert!(extend_ref_address == market_account_object_address, 0);
        assert!(market_account_ref.base_available == base_available, 0);
        assert!(market_account_ref.base_total == base_total, 0);
        assert!(market_account_ref.quote_available == quote_available, 0);
        assert!(market_account_ref.quote_total == quote_total, 0);
    }

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
    public fun ensure_market_registered_for_test() acquires Registry {
        ensure_module_initialized_for_test();
        let trading_pair = get_test_trading_pair();
        let registry_ref = borrow_global<Registry>(@econia);
        if (table::contains(&registry_ref.trading_pair_market_ids, trading_pair)) return;
        mint_fa_apt_to_market_registrant();
        let registrant = get_signer(MARKET_REGISTRANT_FOR_TEST);
        ensure_market_registered(
            &registrant,
            trading_pair.base_metadata,
            trading_pair.quote_metadata
        );
    }

    #[test_only]
    public fun ensure_markets_registered_for_test() acquires Registry {
        ensure_market_registered_for_test();
        let trading_pair_flipped = get_test_trading_pair_flipped();
        let registry_ref = borrow_global<Registry>(@econia);
        if (table::contains(&registry_ref.trading_pair_market_ids, trading_pair_flipped)) return;
        mint_fa_apt_to_market_registrant();
        ensure_market_registered(
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

    #[test, expected_failure(abort_code = E_OPTION_VECTOR_TOO_LONG)]
    fun test_assert_option_vector_is_valid_length_option_vector_too_long() {
        assert_option_vector_is_valid_length(&vector[0, 0]);
    }

    #[test]
    fun test_genesis_values() acquires Registry {
        ensure_module_initialized_for_test();
        let registry_ref = borrow_registry();
        assert_registry_parameters(
            registry_ref.registry_parameters,
            GENESIS_UTILITY_ASSET_METADATA_ADDRESS,
            GENESIS_MARKET_REGISTRATION_FEE,
            GENESIS_ORACLE_FEE,
        );
        assert_market_parameters(
            registry_ref.default_market_parameters,
            GENESIS_DEFAULT_POOL_FEE_RATE_BPS,
            GENESIS_DEFAULT_TAKER_FEE_RATE_BPS,
            GENESIS_DEFAULT_MAX_PRICE_SIG_FIGS,
            GENESIS_DEFAULT_EVICTION_TREE_HEIGHT,
            GENESIS_DEFAULT_EVICTION_PRICE_DIVISOR_ASK,
            GENESIS_DEFAULT_EVICTION_PRICE_DIVISOR_BID,
            GENESIS_DEFAULT_EVICTION_LIQUIDITY_DIVISOR,
        );
    }

    #[test]
    fun test_ensure_market_registered() acquires Market, Registry {
        ensure_markets_registered_for_test();
        let registry_ref = borrow_registry();
        let trading_pair_market_ids_ref = &registry_ref.trading_pair_market_ids;
        let trading_pair = get_test_trading_pair();
        let trading_pair_flipped = get_test_trading_pair_flipped();
        assert!(*table::borrow(trading_pair_market_ids_ref, trading_pair) == 1, 0);
        assert!(*table::borrow(trading_pair_market_ids_ref, trading_pair_flipped) == 2, 0);
        let default_market_parameters = registry_ref.default_market_parameters;
        let market_metadata = *table_with_length::borrow(&registry_ref.markets, 1);
        let market_object = market_metadata.market_object;
        assert!(!object::ungated_transfer_allowed(market_object), 0);
        assert!(object::owner(market_object) == @econia, 0);
        assert!(market_metadata.market_id == 1, 0);
        assert!(market_metadata.trading_pair == trading_pair, 0);
        assert!(market_metadata.market_parameters == default_market_parameters, 0);
        let market_address = object::object_address(&market_metadata.market_object);
        let market_ref = borrow_global<Market>(market_address);
        assert!(market_ref.market_id == 1, 0);
        assert!(market_ref.trading_pair == trading_pair, 0);
        assert!(market_ref.market_parameters == default_market_parameters, 0);
        market_metadata = *table_with_length::borrow(&registry_ref.markets, 2);
        market_object = market_metadata.market_object;
        assert!(!object::ungated_transfer_allowed(market_object), 0);
        assert!(object::owner(market_object) == @econia, 0);
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
    fun test_ensure_market_registered_not_enough_utility_asset() acquires Registry {
        ensure_market_registered_for_test();
        let (base_metadata, quote_metadata) = test_assets::get_metadata();
        ensure_market_registered(
            &get_signer(MARKET_REGISTRANT_FOR_TEST),
            quote_metadata,
            base_metadata,
        );
    }

    #[test, expected_failure(abort_code = E_BASE_QUOTE_METADATA_SAME)]
    fun test_ensure_market_registered_base_quote_metadata_same() acquires Registry {
        ensure_module_initialized_for_test();
        let (metadata, _) = test_assets::get_metadata();
        ensure_market_registered(&get_signer(MARKET_REGISTRANT_FOR_TEST), metadata, metadata);
    }

    #[test]
    fun test_ensure_market_account_registered() acquires MarketAccount, MarketAccounts, Registry {
        ensure_market_registered_for_test();
        let (base_metadata, quote_metadata) = test_assets::get_metadata();
        ensure_market_account_registered(
            &get_signer(USER_FOR_TEST),
            base_metadata,
            quote_metadata
        );
        let registry = borrow_registry();
        let market_id = 1;
        let market_metadata = *table_with_length::borrow(&registry.markets, 1);
        let trading_pair = market_metadata.trading_pair;
        let market_object = market_metadata.market_object;
        let market_accounts_map_ref = &borrow_global<MarketAccounts>(USER_FOR_TEST).map;
        let market_account_metadata = *smart_table::borrow(market_accounts_map_ref, trading_pair);
        assert!(market_account_metadata.market_id == market_id, 0);
        assert!(market_account_metadata.trading_pair == trading_pair, 0);
        assert!(market_account_metadata.market_object == market_object, 0);
        assert!(market_account_metadata.user == USER_FOR_TEST, 0);
        let market_account_object = market_account_metadata.market_account_object;
        assert!(!object::ungated_transfer_allowed(market_account_object), 0);
        assert!(object::owner(market_account_object) == USER_FOR_TEST, 0);
        assert_market_account_fields(
            market_account_object,
            market_id,
            trading_pair,
            market_object,
            USER_FOR_TEST,
            0,
            0,
            0,
            0,
        );
        ensure_market_account_registered(
            &get_signer(USER_FOR_TEST),
            base_metadata,
            quote_metadata
        );
    }

    #[test]
    fun test_update_recognized_markets() acquires Registry {
        ensure_markets_registered_for_test();
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

    #[test]
    fun test_update_registry_parameters() acquires Registry {
        ensure_module_initialized_for_test();
        let econia = get_signer(@econia);
        update_registry_parameters(&econia, vector[], vector[], vector[]);
        assert_registry_parameters(
            borrow_registry().registry_parameters,
            GENESIS_UTILITY_ASSET_METADATA_ADDRESS,
            GENESIS_MARKET_REGISTRATION_FEE,
            GENESIS_ORACLE_FEE,
        );
        test_assets::ensure_assets_initialized();
        let (new_metadata, _) = test_assets::get_metadata();
        let new_metadata_address = object::object_address(&new_metadata);
        update_registry_parameters(&econia, vector[new_metadata_address], vector[1], vector[2]);
        assert_registry_parameters(
            borrow_registry().registry_parameters,
            new_metadata_address,
            1,
            2,
        );
    }

    #[test]
    fun test_update_market_parameters() acquires Market, Registry {
        ensure_market_registered_for_test();
        let econia = get_signer(@econia);
        update_market_parameters(
            &econia,
            vector[1],
            vector[2],
            vector[3],
            vector[4],
            vector[],
            vector[],
            vector[],
            vector[],
        );
        let registry = borrow_registry();
        let markets_ref = &registry.markets;
        let market_metadata = *table_with_length::borrow(markets_ref, 1);
        let market_address = object::object_address(&market_metadata.market_object);
        let market_parameters = market_metadata.market_parameters;
        let market_ref = borrow_global<Market>(market_address);
        assert!(market_ref.market_parameters == market_parameters, 0);
        assert_market_parameters(
            market_parameters,
            2,
            3,
            4,
            GENESIS_DEFAULT_EVICTION_TREE_HEIGHT,
            GENESIS_DEFAULT_EVICTION_PRICE_DIVISOR_ASK,
            GENESIS_DEFAULT_EVICTION_PRICE_DIVISOR_BID,
            GENESIS_DEFAULT_EVICTION_LIQUIDITY_DIVISOR,

        );
        update_market_parameters(
            &econia,
            vector[],
            vector[],
            vector[],
            vector[],
            vector[5],
            vector[6],
            vector[7],
            vector[8],
        );
        assert_market_parameters(
            borrow_registry().default_market_parameters,
            GENESIS_DEFAULT_POOL_FEE_RATE_BPS,
            GENESIS_DEFAULT_TAKER_FEE_RATE_BPS,
            GENESIS_DEFAULT_MAX_PRICE_SIG_FIGS,
            5,
            6,
            7,
            8,
        )
    }

    #[test, expected_failure(abort_code = E_INVALID_MARKET_ID)]
    fun test_update_market_parameters_invalid_market_id() acquires Market, Registry {
        ensure_market_registered_for_test();
        update_market_parameters(
            &get_signer(@econia),
            vector[2],
            vector[],
            vector[],
            vector[],
            vector[],
            vector[],
            vector[],
            vector[],
        );
    }

}
