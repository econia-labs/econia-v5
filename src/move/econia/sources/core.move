// # cspell:words ungated
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
    const GENESIS_ORACLE_FEE: u64 = 0;
    const GENESIS_INTEGRATOR_WITHDRAWAL_FEE: u64 = 0;

    const GENESIS_DEFAULT_POOL_FEE_RATE_BPS: u8 = 30;
    const GENESIS_DEFAULT_TAKER_FEE_RATE_BPS: u8 = 0;
    const GENESIS_DEFAULT_MAX_PRICE_SIG_FIGS: u8 = 4;
    const GENESIS_DEFAULT_EVICTION_TREE_HEIGHT: u8 = 5;
    const GENESIS_DEFAULT_EVICTION_PRICE_DIVISOR_ASK: u128 = 100_000_000_000_000_000_000;
    const GENESIS_DEFAULT_EVICTION_PRICE_DIVISOR_BID: u128 = 100_000_000_000_000_000_000;
    const GENESIS_DEFAULT_EVICTION_LIQUIDITY_DIVISOR: u128 = 1_000_000_000_000_000_000_000_000;
    const GENESIS_DEFAULT_INNER_NODE_ORDER: u8 = 10;
    const GENESIS_DEFAULT_LEAF_NODE_ORDER: u8 = 5;

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
    /// Market is not fully collateralized with base asset.
    const E_MARKET_NOT_COLLATERALIZED_BASE: u64 = 5;
    /// Market is not fully collateralized with quote asset.
    const E_MARKET_NOT_COLLATERALIZED_QUOTE: u64 = 6;
    /// Specified user does not own the given market account.
    const E_DOES_NOT_OWN_MARKET_ACCOUNT: u64 = 7;
    /// Market account does not exist at given address.
    const E_NO_MARKET_ACCOUNT: u64 = 8;

    #[resource_group_member(group = ObjectGroup)]
    struct Market has key {
        market_id: u64,
        trading_pair: TradingPair,
        market_parameters: MarketParameters,
        extend_ref: ExtendRef,
        base_balances: MarketBalances,
        quote_balances: MarketBalances,
    }

    struct MarketBalances has copy, drop, store {
        market_account_deposits: u64,
        book_liquidity: u64,
        pool_liquidity: u64,
    }

    struct MarketMetadata has copy, drop, store {
        market_id: u64,
        market_address: address,
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
        inner_node_order: u8,
        leaf_node_order: u8,
    }

    #[resource_group_member(group = ObjectGroup)]
    struct MarketAccount has key {
        market_id: u64,
        trading_pair: TradingPair,
        market_address: address,
        user: address,
        extend_ref: ExtendRef,
        base_balances: MarketAccountBalances,
        quote_balances: MarketAccountBalances,
    }

    struct MarketAccountBalances has copy, drop, store {
        available: u64,
        total: u64,
    }

    struct MarketAccountBalancesView has copy, drop, store {
        base_balances: MarketAccountBalances,
        quote_balances: MarketAccountBalances,
    }

    struct MarketAccountMetadata has copy, drop, store {
        market_id: u64,
        trading_pair: TradingPair,
        market_address: address,
        user: address,
        market_account_address: address,
    }

    struct MarketAccounts has key {
        map: SmartTable<TradingPair, MarketAccountMetadata>,
    }

    #[resource_group_member(group = ObjectGroup)]
    struct IntegratorFeeStore has key {
        market_id: u64,
        trading_pair: TradingPair,
        market_address: address,
        integrator: address,
        extend_ref: ExtendRef,
        quote_available: u64,
    }

    struct IntegratorFeeStoreMetadata has copy, drop, store {
        market_id: u64,
        trading_pair: TradingPair,
        market_address: address,
        integrator: address,
        integrator_fee_store_address: address,
    }

    struct IntegratorFeeStores has key {
        map: SmartTable<TradingPair, IntegratorFeeStoreMetadata>,
    }

    struct Null has drop, key, store {}

    struct RegistryParameters has copy, drop, store {
        utility_asset_metadata: Object<Metadata>,
        market_registration_fee: u64,
        oracle_fee: u64,
        integrator_withdrawal_fee: u64,
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
        let (constructor_ref, extend_ref) = create_nontransferable_sticky_object(@econia);
        let market_parameters = registry_ref_mut.default_market_parameters;
        let market_signer = object::generate_signer(&constructor_ref);
        let no_balances =
            MarketBalances { market_account_deposits: 0, book_liquidity: 0, pool_liquidity: 0};
        move_to(&market_signer, Market {
            market_id,
            trading_pair,
            market_parameters,
            extend_ref,
            base_balances: no_balances,
            quote_balances: no_balances,
        });
        let market_metadata = MarketMetadata {
            market_id,
            market_address: object::address_from_constructor_ref(&constructor_ref),
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
        let market_accounts_map_ref_mut = &mut borrow_global_mut<MarketAccounts>(user_address).map;
        let trading_pair = TradingPair { base_metadata, quote_metadata };
        if (smart_table::contains(market_accounts_map_ref_mut, trading_pair)) return;
        ensure_market_registered(user, base_metadata, quote_metadata);
        let (market_id, market_address) =
            get_market_id_and_address_for_registered_pair(trading_pair);
        let (constructor_ref, extend_ref) = create_nontransferable_sticky_object(user_address);
        let no_balances = MarketAccountBalances { available: 0, total: 0 };
        move_to(&object::generate_signer(&constructor_ref), MarketAccount {
            market_id,
            trading_pair,
            market_address,
            user: user_address,
            extend_ref,
            base_balances: no_balances,
            quote_balances: no_balances,
        });
        smart_table::add(
            market_accounts_map_ref_mut,
            trading_pair,
            MarketAccountMetadata {
                market_id,
                trading_pair,
                market_address,
                user: user_address,
                market_account_address: object::address_from_constructor_ref(&constructor_ref),
            }
        );
    }

    public entry fun ensure_integrator_fee_store_registered(
        integrator: &signer,
        base_metadata: Object<Metadata>,
        quote_metadata: Object<Metadata>,
    ) acquires IntegratorFeeStores, Registry {
        let integrator_address = signer::address_of(integrator);
        if (!exists<IntegratorFeeStores>(integrator_address)) {
            move_to(integrator, IntegratorFeeStores { map: smart_table::new() });
        };
        let integrator_fee_stores_map_ref_mut =
            &mut borrow_global_mut<IntegratorFeeStores>(integrator_address).map;
        let trading_pair = TradingPair { base_metadata, quote_metadata };
        if (smart_table::contains(integrator_fee_stores_map_ref_mut, trading_pair)) return;
        ensure_market_registered(integrator, base_metadata, quote_metadata);
        let (market_id, market_address) =
            get_market_id_and_address_for_registered_pair(trading_pair);
        let (constructor_ref, extend_ref) =
            create_nontransferable_sticky_object(integrator_address);
        move_to(&object::generate_signer(&constructor_ref), IntegratorFeeStore {
            market_id,
            trading_pair,
            market_address,
            integrator: integrator_address,
            extend_ref,
            quote_available: 0,
        });
        smart_table::add(
            integrator_fee_stores_map_ref_mut,
            trading_pair,
            IntegratorFeeStoreMetadata {
                market_id,
                trading_pair,
                market_address,
                integrator: integrator_address,
                integrator_fee_store_address:
                    object::address_from_constructor_ref(&constructor_ref),
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
        inner_node_order_option: vector<u8>,
        leaf_node_order_option: vector<u8>,
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
                market_metadata_ref_mut.market_address,
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
        set_value_via_option_vector(
            &mut market_parameters_ref_mut.inner_node_order,
            &inner_node_order_option,
        );
        set_value_via_option_vector(
            &mut market_parameters_ref_mut.leaf_node_order,
            &leaf_node_order_option,
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
        integrator_withdrawal_fee_option: vector<u64>,
    ) acquires Registry {
        assert_signer_is_econia(econia);
        let registry_parameters_ref_mut = &mut borrow_registry_mut().registry_parameters;
        set_object_via_address_option_vector(
            &mut registry_parameters_ref_mut.utility_asset_metadata,
            &utility_asset_metadata_address_option,
        );
        set_value_via_option_vector(
            &mut registry_parameters_ref_mut.market_registration_fee,
            &market_registration_fee_option,
        );
        set_value_via_option_vector(
            &mut registry_parameters_ref_mut.oracle_fee,
            &oracle_fee_option,
        );
        set_value_via_option_vector(
            &mut registry_parameters_ref_mut.integrator_withdrawal_fee,
            &integrator_withdrawal_fee_option,
        );
    }

    public entry fun deposit(
        user: &signer,
        market_account_address: address,
        base_amount: u64,
        quote_amount: u64,
    ) acquires Market, MarketAccount {
        assert_market_account_ownership(market_account_address, signer::address_of(user));
        let market_account_ref_mut = borrow_global_mut<MarketAccount>(market_account_address);
        assert_market_fully_collateralized(market_account_ref_mut.market_address);
        let market_ref_mut = borrow_global_mut<Market>(market_account_ref_mut.market_address);
        deposit_asset(user, market_account_ref_mut, market_ref_mut, base_amount, true);
        deposit_asset(user, market_account_ref_mut, market_ref_mut, quote_amount, false);
    }

    fun deposit_asset(
        user: &signer,
        market_account_ref_mut: &mut MarketAccount,
        market_ref_mut: &mut Market,
        amount: u64,
        deposit_base: bool,
    ) {
        let (
            metadata,
            user_balances_ref_mut,
            market_balance_ref_mut,
            market_address,
        ) = preposition_market_account_transfer_vars(
            market_account_ref_mut,
            market_ref_mut,
            deposit_base,
        );
        primary_fungible_store::transfer(
            user,
            metadata,
            market_address,
            amount,
        );
        user_balances_ref_mut.total = user_balances_ref_mut.total + amount;
        user_balances_ref_mut.available = user_balances_ref_mut.available + amount;
        *market_balance_ref_mut = *market_balance_ref_mut + amount;
    }

    fun preposition_market_account_transfer_vars(
        market_account_ref_mut: &mut MarketAccount,
        market_ref_mut: &mut Market,
        transfer_base: bool,
    ): (
        Object<Metadata>,
        &mut MarketAccountBalances,
        &mut u64,
        address,
    ) {
        let (
            metadata,
            user_balances_ref_mut,
            market_balance_ref_mut,
        ) = if (transfer_base) (
            market_account_ref_mut.trading_pair.base_metadata,
            &mut market_account_ref_mut.base_balances,
            &mut market_ref_mut.base_balances.market_account_deposits,
        ) else (
            market_account_ref_mut.trading_pair.quote_metadata,
            &mut market_account_ref_mut.quote_balances,
            &mut market_ref_mut.quote_balances.market_account_deposits,
        );
        (
            metadata,
            user_balances_ref_mut,
            market_balance_ref_mut,
            market_account_ref_mut.market_address,
        )
    }

    #[view]
    public fun market_account_balances(
        market_account_address: address
    ): MarketAccountBalancesView
    acquires MarketAccount {
        assert_market_account_exists(market_account_address);
        let market_account_ref = borrow_global<MarketAccount>(market_account_address);
        let base_balances = market_account_ref.base_balances;
        let quote_balances = market_account_ref.quote_balances;
        MarketAccountBalancesView { base_balances, quote_balances }
    }

    fun assert_market_account_exists(
        market_account_address: address,
    ) {
        assert!(exists<MarketAccount>(market_account_address), E_NO_MARKET_ACCOUNT);
    }

    fun assert_market_account_ownership(
        market_account_address: address,
        user_address: address,
    ) acquires MarketAccount {
        assert_market_account_exists(market_account_address);
        let market_account_ref = borrow_global<MarketAccount>(market_account_address);
        assert!(market_account_ref.user == user_address, E_DOES_NOT_OWN_MARKET_ACCOUNT);
    }

    fun assert_market_fully_collateralized(market_address: address) acquires Market {
        assert_asset_fully_collateralized(
            market_address,
            true,
        );
        assert_asset_fully_collateralized(
            market_address,
            false,
        );
    }

    fun assert_asset_fully_collateralized(
        market_address: address,
        check_base: bool,
    ) acquires Market {
        let market_ref = borrow_global<Market>(market_address);
        let (asset_metadata, asset_amounts, error_code) = if (check_base) (
            market_ref.trading_pair.base_metadata,
            market_ref.base_balances,
            E_MARKET_NOT_COLLATERALIZED_BASE,
        ) else (
            market_ref.trading_pair.quote_metadata,
            market_ref.quote_balances,
            E_MARKET_NOT_COLLATERALIZED_QUOTE,
        );
        let balance = primary_fungible_store::balance(market_address, asset_metadata);
        let minimum_balance = asset_amounts.market_account_deposits + asset_amounts.pool_liquidity;
        assert!(balance >= minimum_balance, error_code);
    }

    fun create_nontransferable_sticky_object(owner: address): (ConstructorRef, ExtendRef) {
        let constructor_ref = object::create_sticky_object(owner);
        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        object::disable_ungated_transfer(&transfer_ref);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        (constructor_ref, extend_ref)
    }

    fun get_market_id_and_address_for_registered_pair(trading_pair: TradingPair): (
        u64,
        address,
    ) acquires Registry {
        let registry_ref = borrow_registry();
        let trading_pair_market_ids_ref = &registry_ref.trading_pair_market_ids;
        let market_id = *table::borrow(trading_pair_market_ids_ref, trading_pair);
        let market_address =
            table_with_length::borrow(&registry_ref.markets, market_id).market_address;
        (market_id, market_address)
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
                integrator_withdrawal_fee: GENESIS_INTEGRATOR_WITHDRAWAL_FEE,
            },
            default_market_parameters: MarketParameters {
                pool_fee_rate_bps: GENESIS_DEFAULT_POOL_FEE_RATE_BPS,
                taker_fee_rate_bps: GENESIS_DEFAULT_TAKER_FEE_RATE_BPS,
                max_price_sig_figs: GENESIS_DEFAULT_MAX_PRICE_SIG_FIGS,
                eviction_tree_height: GENESIS_DEFAULT_EVICTION_TREE_HEIGHT,
                eviction_price_divisor_ask: GENESIS_DEFAULT_EVICTION_PRICE_DIVISOR_ASK,
                eviction_price_divisor_bid: GENESIS_DEFAULT_EVICTION_PRICE_DIVISOR_BID,
                eviction_liquidity_divisor: GENESIS_DEFAULT_EVICTION_LIQUIDITY_DIVISOR,
                inner_node_order: GENESIS_DEFAULT_INNER_NODE_ORDER,
                leaf_node_order: GENESIS_DEFAULT_LEAF_NODE_ORDER,
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
    const INTEGRATOR_FOR_TEST: address = @0xcad;
    #[test_only]
    const MARKET_ID_FOR_TEST: u64 = 1;

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
        inner_node_order: u8,
        leaf_node_order: u8,
    ) {
        assert!(market_parameters.pool_fee_rate_bps == pool_fee_rate_bps, 0);
        assert!(market_parameters.taker_fee_rate_bps == taker_fee_rate_bps, 0);
        assert!(market_parameters.max_price_sig_figs == max_price_sig_figs, 0);
        assert!(market_parameters.eviction_tree_height == eviction_tree_height, 0);
        assert!(market_parameters.eviction_price_divisor_ask == eviction_price_divisor_ask, 0);
        assert!(market_parameters.eviction_price_divisor_bid == eviction_price_divisor_bid, 0);
        assert!(market_parameters.eviction_liquidity_divisor == eviction_liquidity_divisor, 0);
        assert!(market_parameters.inner_node_order == inner_node_order, 0);
        assert!(market_parameters.leaf_node_order == leaf_node_order, 0);
    }

    #[test_only]
    public fun assert_registry_parameters(
        registry_parameters: RegistryParameters,
        utility_asset_metadata_address: address,
        market_registration_fee: u64,
        oracle_fee: u64,
        integrator_withdrawal_fee: u64,
    ) {
        let utility_asset_metadata_address_to_check =
            object::object_address(&registry_parameters.utility_asset_metadata);
        assert!(utility_asset_metadata_address_to_check == utility_asset_metadata_address, 0);
        assert!(registry_parameters.market_registration_fee == market_registration_fee, 0);
        assert!(registry_parameters.oracle_fee == oracle_fee, 0);
        assert!(registry_parameters.integrator_withdrawal_fee == integrator_withdrawal_fee, 0);
    }

    #[test_only]
    public fun assert_market_account_balances(
        market_account_address: address,
        base_available: u64,
        base_total: u64,
        quote_available: u64,
        quote_total: u64,
    ) acquires MarketAccount {
        let balances_view = market_account_balances(market_account_address);
        assert!(balances_view.base_balances.available == base_available, 0);
        assert!(balances_view.base_balances.total == base_total, 0);
        assert!(balances_view.quote_balances.available == quote_available, 0);
        assert!(balances_view.quote_balances.total == quote_total, 0);
    }

    #[test_only]
    public fun assert_market_account_fields(
        market_account_address: address,
        market_id: u64,
        trading_pair: TradingPair,
        market_address: address,
        user: address,
        base_available: u64,
        base_total: u64,
        quote_available: u64,
        quote_total: u64,
    ) acquires MarketAccount {
        let market_account_ref = borrow_global<MarketAccount>(market_account_address);
        assert!(market_account_ref.market_id == market_id, 0);
        assert!(market_account_ref.trading_pair == trading_pair, 0);
        assert!(market_account_ref.market_address == market_address, 0);
        assert!(market_account_ref.user == user, 0);
        let extend_ref_address = object::address_from_extend_ref(&market_account_ref.extend_ref);
        assert!(extend_ref_address == market_account_address, 0);
        assert!(market_account_ref.base_balances.available == base_available, 0);
        assert!(market_account_ref.base_balances.total == base_total, 0);
        assert!(market_account_ref.quote_balances.available == quote_available, 0);
        assert!(market_account_ref.quote_balances.total == quote_total, 0);
    }

    #[test_only]
    public fun assert_integrator_fee_store_fields(
        integrator_fee_store_address: address,
        market_id: u64,
        trading_pair: TradingPair,
        market_address: address,
        integrator: address,
        quote_available: u64,
    ) acquires IntegratorFeeStore {
        let integrator_fee_store_ref =
            borrow_global<IntegratorFeeStore>(integrator_fee_store_address);
        assert!(integrator_fee_store_ref.market_id == market_id, 0);
        assert!(integrator_fee_store_ref.trading_pair == trading_pair, 0);
        assert!(integrator_fee_store_ref.market_address == market_address, 0);
        assert!(integrator_fee_store_ref.integrator == integrator, 0);
        let extend_ref_address =
            object::address_from_extend_ref(&integrator_fee_store_ref.extend_ref);
        assert!(extend_ref_address == integrator_fee_store_address, 0);
        assert!(integrator_fee_store_ref.quote_available == quote_available, 0);
    }


    #[test_only]
    public fun ensure_module_initialized_for_test() {
        aptos_coin::ensure_initialized_with_fa_metadata_for_test();
        if (!exists<Registry>(@econia)) init_module(&get_signer(@econia));
    }

    #[test_only]
    public fun get_test_market_address(): address acquires Registry {
        ensure_market_registered_for_test();
        let registry_ref = borrow_global<Registry>(@econia);
        table_with_length::borrow(&registry_ref.markets, MARKET_ID_FOR_TEST).market_address
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
    public fun ensure_market_account_registered_for_test(): (
        address,
        address,
    ) acquires MarketAccounts, Registry {
        ensure_market_registered_for_test();
        let (base_metadata, quote_metadata) = test_assets::get_metadata();
        ensure_market_account_registered(&get_signer(USER_FOR_TEST), base_metadata, quote_metadata);
        let market_address = get_test_market_address();
        let market_accounts_map_ref_mut = &mut borrow_global_mut<MarketAccounts>(USER_FOR_TEST).map;
        let market_account_metadata_ref =
            smart_table::borrow(market_accounts_map_ref_mut, get_test_trading_pair());
        let market_account_address = market_account_metadata_ref.market_account_address;
        (market_address, market_account_address)
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

    #[test, expected_failure(abort_code = E_NO_MARKET_ACCOUNT)]
    fun test_assert_market_account_exists_no_market_account() {
        assert_market_account_exists(@0x0);
    }

    #[test, expected_failure(abort_code = E_DOES_NOT_OWN_MARKET_ACCOUNT)]
    fun test_assert_market_account_ownership_does_not_own_market_account()
    acquires
        MarketAccount,
        MarketAccounts,
        Registry,
    {
        let (_, market_account_address) = ensure_market_account_registered_for_test();
        assert_market_account_ownership(market_account_address, @0x0);
    }

    #[test, expected_failure(abort_code = E_MARKET_NOT_COLLATERALIZED_BASE)]
    fun test_assert_market_fully_collateralized_market_not_collateralized_base()
    acquires
        MarketAccount,
        MarketAccounts,
        Market,
        Registry,
    {
        let (_, market_account_address) = ensure_market_account_registered_for_test();
        test_assets::mint(USER_FOR_TEST, 100, 200);
        deposit(&get_signer(USER_FOR_TEST), market_account_address, 100, 200);
        let market_address = get_test_market_address();
        test_assets::burn(market_address, 1, 0);
        assert_market_fully_collateralized(market_address);
    }

    #[test, expected_failure(abort_code = E_MARKET_NOT_COLLATERALIZED_QUOTE)]
    fun test_assert_market_fully_collateralized_market_not_collateralized_quote()
    acquires
        MarketAccount,
        MarketAccounts,
        Market,
        Registry,
    {
        let (_, market_account_address) = ensure_market_account_registered_for_test();
        test_assets::mint(USER_FOR_TEST, 100, 200);
        deposit(&get_signer(USER_FOR_TEST), market_account_address, 100, 200);
        let market_address = get_test_market_address();
        test_assets::burn(market_address, 0, 1);
        assert_market_fully_collateralized(market_address);
    }

    #[test]
    fun test_create_nontransferable_sticky_object() {
        let (constructor_ref, _) = create_nontransferable_sticky_object(@econia);
        move_to(&object::generate_signer(&constructor_ref), Null {});
        let object = object::object_from_constructor_ref(&constructor_ref);
        assert!(!object::ungated_transfer_allowed<Null>(object), 0);
        assert!(object::owner(object) == @econia, 0);
    }

    #[test]
    fun test_deposit() acquires Market, MarketAccount, MarketAccounts, Registry {
        let (_, market_account_address) = ensure_market_account_registered_for_test();
        test_assets::mint(USER_FOR_TEST, 123, 456);
        deposit(&get_signer(USER_FOR_TEST), market_account_address, 100, 200);
        assert_market_account_balances(
            market_account_address,
            100,
            100,
            200,
            200,
        )
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
            GENESIS_INTEGRATOR_WITHDRAWAL_FEE,
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
            GENESIS_DEFAULT_INNER_NODE_ORDER,
            GENESIS_DEFAULT_LEAF_NODE_ORDER,
        );
    }

    #[test]
    fun test_ensure_market_registered() acquires Market, Registry {
        ensure_markets_registered_for_test();
        let registry_ref = borrow_registry();
        let trading_pair_market_ids_ref = &registry_ref.trading_pair_market_ids;
        let trading_pair = get_test_trading_pair();
        let trading_pair_flipped = get_test_trading_pair_flipped();
        assert!(*table::borrow(trading_pair_market_ids_ref, trading_pair) == MARKET_ID_FOR_TEST, 0);
        assert!(*table::borrow(trading_pair_market_ids_ref, trading_pair_flipped) == 2, 0);
        let default_market_parameters = registry_ref.default_market_parameters;
        let market_metadata = *table_with_length::borrow(&registry_ref.markets, 1);
        assert!(market_metadata.market_id == 1, 0);
        assert!(market_metadata.trading_pair == trading_pair, 0);
        assert!(market_metadata.market_parameters == default_market_parameters, 0);
        let market_ref = borrow_global<Market>(market_metadata.market_address);
        assert!(market_ref.market_id == MARKET_ID_FOR_TEST, 0);
        assert!(market_ref.trading_pair == trading_pair, 0);
        assert!(market_ref.market_parameters == default_market_parameters, 0);
        market_metadata = *table_with_length::borrow(&registry_ref.markets, 2);
        assert!(market_metadata.market_id == 2, 0);
        assert!(market_metadata.trading_pair == trading_pair_flipped, 0);
        assert!(market_metadata.market_parameters == default_market_parameters, 0);
        market_ref = borrow_global<Market>(market_metadata.market_address);
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
        let market_metadata = *table_with_length::borrow(&registry.markets, MARKET_ID_FOR_TEST);
        let trading_pair = market_metadata.trading_pair;
        let market_address = market_metadata.market_address;
        let market_accounts_map_ref = &borrow_global<MarketAccounts>(USER_FOR_TEST).map;
        let market_account_metadata = *smart_table::borrow(market_accounts_map_ref, trading_pair);
        assert!(market_account_metadata.market_id == MARKET_ID_FOR_TEST, 0);
        assert!(market_account_metadata.trading_pair == trading_pair, 0);
        assert!(market_account_metadata.market_address == market_address, 0);
        assert!(market_account_metadata.user == USER_FOR_TEST, 0);
        assert_market_account_fields(
            market_account_metadata.market_account_address,
            MARKET_ID_FOR_TEST,
            trading_pair,
            market_address,
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
    fun test_ensure_integrator_fee_store_registered() acquires
        IntegratorFeeStore,
        IntegratorFeeStores,
        Registry
    {
        ensure_market_registered_for_test();
        let (base_metadata, quote_metadata) = test_assets::get_metadata();
        ensure_integrator_fee_store_registered(
            &get_signer(INTEGRATOR_FOR_TEST),
            base_metadata,
            quote_metadata
        );
        let registry = borrow_registry();
        let market_metadata = *table_with_length::borrow(&registry.markets, MARKET_ID_FOR_TEST);
        let trading_pair = market_metadata.trading_pair;
        let market_address = market_metadata.market_address;
        let integrator_fee_stores_map_ref =
            &borrow_global<IntegratorFeeStores>(INTEGRATOR_FOR_TEST).map;
        let integrator_fee_store_metadata =
            *smart_table::borrow(integrator_fee_stores_map_ref, trading_pair);
        assert!(integrator_fee_store_metadata.market_id == MARKET_ID_FOR_TEST, 0);
        assert!(integrator_fee_store_metadata.trading_pair == trading_pair, 0);
        assert!(integrator_fee_store_metadata.market_address == market_address, 0);
        assert!(integrator_fee_store_metadata.integrator == INTEGRATOR_FOR_TEST, 0);
        assert_integrator_fee_store_fields(
            integrator_fee_store_metadata.integrator_fee_store_address,
            MARKET_ID_FOR_TEST,
            trading_pair,
            market_address,
            INTEGRATOR_FOR_TEST,
            0,
        );
        ensure_integrator_fee_store_registered(
            &get_signer(INTEGRATOR_FOR_TEST),
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
        update_registry_parameters(&econia, vector[], vector[], vector[], vector[]);
        assert_registry_parameters(
            borrow_registry().registry_parameters,
            GENESIS_UTILITY_ASSET_METADATA_ADDRESS,
            GENESIS_MARKET_REGISTRATION_FEE,
            GENESIS_ORACLE_FEE,
            GENESIS_INTEGRATOR_WITHDRAWAL_FEE,
        );
        test_assets::ensure_assets_initialized();
        let (new_metadata, _) = test_assets::get_metadata();
        let new_metadata_address = object::object_address(&new_metadata);
        update_registry_parameters(
            &econia,
            vector[new_metadata_address],
            vector[1],
            vector[2],
            vector[3]
        );
        assert_registry_parameters(
            borrow_registry().registry_parameters,
            new_metadata_address,
            1,
            2,
            3,
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
            vector[],
            vector[],
        );
        let registry = borrow_registry();
        let markets_ref = &registry.markets;
        let market_metadata = *table_with_length::borrow(markets_ref, 1);
        let market_parameters = market_metadata.market_parameters;
        let market_ref = borrow_global<Market>(market_metadata.market_address);
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
            GENESIS_DEFAULT_INNER_NODE_ORDER,
            GENESIS_DEFAULT_LEAF_NODE_ORDER,
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
            vector[9],
            vector[10],
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
            9,
            10,
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
            vector[],
            vector[],
        );
    }

}
