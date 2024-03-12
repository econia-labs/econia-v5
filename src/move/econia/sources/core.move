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
    #[test_only]
    use std::features;
    #[test_only]
    use econia::rational;

    const GENESIS_UTILITY_ASSET_METADATA_ADDRESS: address = @aptos_fungible_asset;
    const GENESIS_MARKET_REGISTRATION_FEE: u64 = 100_000_000;
    const GENESIS_ORACLE_FEE: u64 = 0;
    const GENESIS_INTEGRATOR_WITHDRAWAL_FEE: u64 = 0;
    const GENESIS_BOOK_MAP_INNER_NODE_ORDER: u16 = 7;
    const GENESIS_BOOK_MAP_LEAF_NODE_ORDER: u16 = 10;
    const GENESIS_TICK_MAP_INNER_NODE_ORDER: u16 = 20;
    const GENESIS_TICK_MAP_LEAF_NODE_ORDER: u16 = 12;

    const GENESIS_DEFAULT_POOL_FEE_RATE: u16 = 3_000;
    const GENESIS_DEFAULT_PROTOCOL_FEE_RATE: u16 = 0;
    const GENESIS_DEFAULT_MAX_PRICE_SIG_FIGS: u8 = 4;
    const GENESIS_DEFAULT_EVICTION_TREE_HEIGHT: u8 = 5;
    const GENESIS_DEFAULT_EVICTION_PRICE_RATIO_ASK_NUMERATOR: u64 = 1;
    const GENESIS_DEFAULT_EVICTION_PRICE_RATIO_ASK_DENOMINATOR: u64 = 3;
    const GENESIS_DEFAULT_EVICTION_PRICE_RATIO_BID_NUMERATOR: u64 = 1;
    const GENESIS_DEFAULT_EVICTION_PRICE_RATIO_BID_DENOMINATOR: u64 = 5;
    const GENESIS_DEFAULT_EVICTION_LIQUIDITY_RATIO_NUMERATOR: u64 = 1;
    const GENESIS_DEFAULT_EVICTION_LIQUIDITY_RATIO_DENOMINATOR: u64 = 100_000;
    const GENESIS_DEFAULT_INNER_NODE_ORDER: u8 = 10;
    const GENESIS_DEFAULT_LEAF_NODE_ORDER: u8 = 5;

    const COMPARE_LEFT_GREATER: u8 = 0;
    const COMPARE_RIGHT_GREATER: u8 = 1;
    const COMPARE_EQUAL: u8 = 2;

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
    /// Specified user does not own the given open orders resource.
    const E_DOES_NOT_OWN_OPEN_ORDERS: u64 = 7;
    /// Open orders resource does not exist at given address.
    const E_NO_OPEN_ORDERS: u64 = 8;
    /// Requested withdrawal amount exceeds expected vault balance for base.
    const E_WITHDRAWAL_EXCEEDS_EXPECTED_VAULT_BALANCE_BASE: u64 = 9;
    /// Requested withdrawal amount exceeds expected vault balance for quote.
    const E_WITHDRAWAL_EXCEEDS_EXPECTED_VAULT_BALANCE_QUOTE: u64 = 10;
    /// The protocol is inactive.
    const E_INACTIVE: u64 = 11;

    #[resource_group_member(group = ObjectGroup)]
    struct Market has key {
        market_id: u64,
        market_address: address,
        trading_pair: TradingPair,
        market_parameters: MarketParameters,
        extend_ref: ExtendRef,
        base_balances: AssetBalances,
        quote_balances: AssetBalances,
    }

    struct AssetBalances has copy, drop, store {
        book_liquidity: u64,
        pool_liquidity: u64,
        unclaimed_pool_fees: u64,
        unclaimed_protocol_fees: u64,
    }

    struct MarketMetadata has copy, drop, store {
        market_id: u64,
        market_address: address,
        trading_pair: TradingPair,
        market_parameters: MarketParameters,
    }

    struct MarketParameters has copy, drop, store {
        pool_fee_rate: u16,
        protocol_fee_rate: u16,
        max_price_sig_figs: u8,
        eviction_tree_height: u8,
        eviction_price_ratio_ask: Rational,
        eviction_price_ratio_bid: Rational,
        eviction_liquidity_ratio: Rational,
    }

    struct Rational has copy, drop, store {
        numerator: u64,
        denominator: u64,
    }

    #[resource_group_member(group = ObjectGroup)]
    struct OpenOrders has key {
        market_id: u64,
        trading_pair: TradingPair,
        market_address: address,
        user: address,
        open_orders_address: address,
    }

    struct OpenOrdersMetadata has copy, drop, store {
        market_id: u64,
        trading_pair: TradingPair,
        market_address: address,
        user: address,
        open_orders_address: address,
    }

    struct OpenOrdersByMarket has key {
        map: SmartTable<u64, OpenOrdersMetadata>,
    }

    struct Null has drop, key, store {}

    struct RegistryParameters has copy, drop, store {
        utility_asset_metadata: Object<Metadata>,
        market_registration_fee: u64,
        oracle_fee: u64,
        integrator_withdrawal_fee: u64,
        book_map_node_orders: NewMarketNodeOrders,
        tick_map_node_orders: NewMarketNodeOrders,
    }

    struct NewMarketNodeOrders has copy, drop, store {
        inner_node_order: u16,
        leaf_node_order: u16,
    }

    struct Registry has key {
        markets: TableWithLength<u64, MarketMetadata>,
        trading_pair_market_ids: Table<TradingPair, u64>,
        recognized_market_ids: SmartTable<u64, Null>,
        registry_parameters: RegistryParameters,
        default_market_parameters: MarketParameters,
    }

    struct Status has key {
        active: bool,
    }

    struct TradingPair has copy, drop, store {
        base_metadata: Object<Metadata>,
        quote_metadata: Object<Metadata>,
    }

    public entry fun ensure_market_registered(
        registrant: &signer,
        base_metadata: Object<Metadata>,
        quote_metadata: Object<Metadata>,
    ) acquires
        Registry,
        Status
    {
        let registry_ref_mut = borrow_registry_mut();
        let trading_pair = TradingPair { base_metadata, quote_metadata };
        let trading_pair_market_ids_ref_mut = &mut registry_ref_mut.trading_pair_market_ids;
        if (table::contains(trading_pair_market_ids_ref_mut, trading_pair)) return;
        assert_active_status();
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
        let market_address = object::address_from_constructor_ref(&constructor_ref);
        let no_balances = AssetBalances {
            book_liquidity: 0,
            pool_liquidity: 0,
            unclaimed_pool_fees: 0,
            unclaimed_protocol_fees: 0,
        };
        move_to(&market_signer, Market {
            market_id,
            market_address,
            trading_pair,
            market_parameters,
            extend_ref,
            base_balances: no_balances,
            quote_balances: no_balances,
        });
        let market_metadata = MarketMetadata {
            market_id,
            market_address,
            trading_pair,
            market_parameters,
        };
        table_with_length::add(markets_ref_mut, market_id, market_metadata);
        table::add(trading_pair_market_ids_ref_mut, trading_pair, market_id);
    }

    public entry fun ensure_open_orders_registered(
        user: &signer,
        base_metadata: Object<Metadata>,
        quote_metadata: Object<Metadata>,
    ) acquires
        OpenOrdersByMarket,
        Registry,
        Status,
    {
        assert_active_status();
        let user_address = signer::address_of(user);
        if (!exists<OpenOrdersByMarket>(user_address)) {
            move_to(user, OpenOrdersByMarket { map: smart_table::new() });
        };
        ensure_market_registered(user, base_metadata, quote_metadata);
        let trading_pair = TradingPair { base_metadata, quote_metadata };
        let (market_id, market_address) =
            get_market_id_and_address_for_registered_pair(trading_pair);
        let open_orders_map_ref_mut = &mut borrow_global_mut<OpenOrdersByMarket>(user_address).map;
        if (smart_table::contains(open_orders_map_ref_mut, market_id)) return;
        let (constructor_ref, _) = create_nontransferable_sticky_object(user_address);
        let open_orders_address = object::address_from_constructor_ref(&constructor_ref);
        move_to(&object::generate_signer(&constructor_ref), OpenOrders {
            market_id,
            trading_pair,
            market_address,
            user: user_address,
            open_orders_address,
        });
        smart_table::add(
            open_orders_map_ref_mut,
            market_id,
            OpenOrdersMetadata {
                market_id,
                trading_pair,
                market_address,
                user: user_address,
                open_orders_address,
            }
        );
    }

    public entry fun update_market_parameters(
        econia: &signer,
        market_id_option: vector<u64>,
        pool_fee_rate_option: vector<u16>,
        protocol_fee_rate_option: vector<u16>,
        max_price_sig_figs_option: vector<u8>,
        eviction_tree_height_option: vector<u8>,
        eviction_price_ratio_ask_numerator_option: vector<u64>,
        eviction_price_ratio_ask_denominator_option: vector<u64>,
        eviction_price_ratio_bid_numerator_option: vector<u64>,
        eviction_price_ratio_bid_denominator_option: vector<u64>,
        eviction_liquidity_ratio_numerator_option: vector<u64>,
        eviction_liquidity_ratio_denominator_option: vector<u64>,
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
            &mut market_parameters_ref_mut.pool_fee_rate,
            &pool_fee_rate_option,
        );
        set_value_via_option_vector(
            &mut market_parameters_ref_mut.protocol_fee_rate,
            &protocol_fee_rate_option,
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
            &mut market_parameters_ref_mut.eviction_price_ratio_ask.numerator,
            &eviction_price_ratio_ask_numerator_option,
        );
        set_value_via_option_vector(
            &mut market_parameters_ref_mut.eviction_price_ratio_ask.denominator,
            &eviction_price_ratio_ask_denominator_option,
        );
        set_value_via_option_vector(
            &mut market_parameters_ref_mut.eviction_price_ratio_bid.numerator,
            &eviction_price_ratio_bid_numerator_option,
        );
        set_value_via_option_vector(
            &mut market_parameters_ref_mut.eviction_price_ratio_bid.denominator,
            &eviction_price_ratio_bid_denominator_option,
        );
        set_value_via_option_vector(
            &mut market_parameters_ref_mut.eviction_liquidity_ratio.numerator,
            &eviction_liquidity_ratio_numerator_option,
        );
        set_value_via_option_vector(
            &mut market_parameters_ref_mut.eviction_liquidity_ratio.denominator,
            &eviction_liquidity_ratio_denominator_option,
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
        book_map_inner_node_order_option: vector<u16>,
        book_map_leaf_node_order_option: vector<u16>,
        tick_map_inner_node_order_option: vector<u16>,
        tick_map_leaf_node_order_option: vector<u16>,
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
        set_value_via_option_vector(
            &mut registry_parameters_ref_mut.book_map_node_orders.inner_node_order,
            &book_map_inner_node_order_option,
        );
        set_value_via_option_vector(
            &mut registry_parameters_ref_mut.book_map_node_orders.leaf_node_order,
            &book_map_leaf_node_order_option,
        );
        set_value_via_option_vector(
            &mut registry_parameters_ref_mut.tick_map_node_orders.inner_node_order,
            &tick_map_inner_node_order_option,
        );
        set_value_via_option_vector(
            &mut registry_parameters_ref_mut.tick_map_node_orders.leaf_node_order,
            &tick_map_leaf_node_order_option,
        );
    }

    public entry fun set_status(econia: &signer, active: bool) acquires Status {
        assert_signer_is_econia(econia);
        borrow_global_mut<Status>(@econia).active = active
    }

    fun assert_active_status() acquires Status {
        assert!(borrow_global<Status>(@econia).active, E_INACTIVE);
    }

    fun assert_open_orders_exists(
        open_orders_address: address,
    ) {
        assert!(exists<OpenOrders>(open_orders_address), E_NO_OPEN_ORDERS);
    }

    fun assert_open_orders_owner(open_orders_ref: &OpenOrders, user: address) {
        assert!(open_orders_ref.user == user, E_DOES_NOT_OWN_OPEN_ORDERS);
    }

    fun assert_market_fully_collateralized(market_ref: &Market) {
        assert_asset_fully_collateralized(market_ref, true);
        assert_asset_fully_collateralized(market_ref, false);
    }

    fun assert_asset_fully_collateralized(market_ref: &Market, check_base: bool) {
        let (asset_metadata, asset_amounts, error_code) = if (check_base) (
            market_ref.trading_pair.base_metadata,
            market_ref.base_balances,
            E_MARKET_NOT_COLLATERALIZED_BASE,
        ) else (
            market_ref.trading_pair.quote_metadata,
            market_ref.quote_balances,
            E_MARKET_NOT_COLLATERALIZED_QUOTE,
        );
        let balance = primary_fungible_store::balance(market_ref.market_address, asset_metadata);
        let minimum_balance = expected_vault_balance(&asset_amounts);
        assert!(balance >= minimum_balance, error_code);
    }

    fun expected_vault_balance(asset_amounts_ref: &AssetBalances): u64 {
        asset_amounts_ref.book_liquidity +
            asset_amounts_ref.pool_liquidity +
            asset_amounts_ref.unclaimed_pool_fees +
            asset_amounts_ref.unclaimed_protocol_fees
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
                book_map_node_orders: NewMarketNodeOrders {
                    inner_node_order: GENESIS_BOOK_MAP_INNER_NODE_ORDER,
                    leaf_node_order: GENESIS_BOOK_MAP_LEAF_NODE_ORDER,
                },
                tick_map_node_orders: NewMarketNodeOrders {
                    inner_node_order: GENESIS_TICK_MAP_INNER_NODE_ORDER,
                    leaf_node_order: GENESIS_TICK_MAP_LEAF_NODE_ORDER,
                },
            },
            default_market_parameters: MarketParameters {
                pool_fee_rate: GENESIS_DEFAULT_POOL_FEE_RATE,
                protocol_fee_rate: GENESIS_DEFAULT_PROTOCOL_FEE_RATE,
                max_price_sig_figs: GENESIS_DEFAULT_MAX_PRICE_SIG_FIGS,
                eviction_tree_height: GENESIS_DEFAULT_EVICTION_TREE_HEIGHT,
                eviction_price_ratio_ask: Rational {
                    numerator: GENESIS_DEFAULT_EVICTION_PRICE_RATIO_ASK_NUMERATOR,
                    denominator: GENESIS_DEFAULT_EVICTION_PRICE_RATIO_ASK_DENOMINATOR,
                },
                eviction_price_ratio_bid: Rational {
                    numerator: GENESIS_DEFAULT_EVICTION_PRICE_RATIO_BID_NUMERATOR,
                    denominator: GENESIS_DEFAULT_EVICTION_PRICE_RATIO_BID_DENOMINATOR,
                },
                eviction_liquidity_ratio: Rational {
                    numerator: GENESIS_DEFAULT_EVICTION_LIQUIDITY_RATIO_NUMERATOR,
                    denominator: GENESIS_DEFAULT_EVICTION_LIQUIDITY_RATIO_DENOMINATOR,
                },
            },
        });
        move_to(econia, Status { active: true });
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

    fun socialize_withdrawal_amount(
        market_ref: &Market,
        amount: u64,
        withdraw_base: bool,
    ): u64 {
        let (balances_ref, asset_metadata, error_code) = if (withdraw_base) (
            &market_ref.base_balances,
            market_ref.trading_pair.base_metadata,
            E_WITHDRAWAL_EXCEEDS_EXPECTED_VAULT_BALANCE_BASE,
        ) else (
            &market_ref.quote_balances,
            market_ref.trading_pair.quote_metadata,
            E_WITHDRAWAL_EXCEEDS_EXPECTED_VAULT_BALANCE_QUOTE,
        );
        let expected_vault_balance = expected_vault_balance(balances_ref);
        let actual_vault_balance =
            primary_fungible_store::balance(market_ref.market_address, asset_metadata);
        assert!(amount <= expected_vault_balance, error_code);
        if (actual_vault_balance >= expected_vault_balance) return amount;
        let numerator = (amount as u128) * (actual_vault_balance as u128);
        let denominator = (expected_vault_balance as u128);
        (numerator / denominator as u64)
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
        pool_fee_rate: u16,
        protocol_fee_rate: u16,
        max_price_sig_figs: u8,
        eviction_tree_height: u8,
        eviction_price_ratio_ask_numerator: u64,
        eviction_price_ratio_ask_denominator: u64,
        eviction_price_ratio_bid_numerator: u64,
        eviction_price_ratio_bid_denominator: u64,
        eviction_liquidity_ratio_numerator: u64,
        eviction_liquidity_ratio_denominator: u64,
    ) {
        assert!(market_parameters.pool_fee_rate == pool_fee_rate, 0);
        assert!(market_parameters.protocol_fee_rate == protocol_fee_rate, 0);
        assert!(market_parameters.max_price_sig_figs == max_price_sig_figs, 0);
        assert!(market_parameters.eviction_tree_height == eviction_tree_height, 0);
        let ratio = market_parameters.eviction_price_ratio_ask;
        assert!(ratio.numerator == eviction_price_ratio_ask_numerator, 0);
        assert!(ratio.denominator == eviction_price_ratio_ask_denominator, 0);
        ratio = market_parameters.eviction_price_ratio_bid;
        assert!(ratio.numerator == eviction_price_ratio_bid_numerator, 0);
        assert!(ratio.denominator == eviction_price_ratio_bid_denominator, 0);
        ratio = market_parameters.eviction_liquidity_ratio;
        assert!(ratio.numerator == eviction_liquidity_ratio_numerator, 0);
        assert!(ratio.denominator == eviction_liquidity_ratio_denominator, 0);
    }

    #[test_only]
    public fun assert_market_balances(
        market_address: address,
        base_book_liquidity: u64,
        base_pool_liquidity: u64,
        base_unclaimed_pool_fees: u64,
        base_unclaimed_protocol_fees: u64,
        quote_book_liquidity: u64,
        quote_pool_liquidity: u64,
        quote_unclaimed_pool_fees: u64,
        quote_unclaimed_protocol_fees: u64,
    ) acquires Market {
        let market_ref = borrow_global<Market>(market_address);
        let base_balances = market_ref.base_balances;
        assert!(base_balances.book_liquidity == base_book_liquidity, 0);
        assert!(base_balances.pool_liquidity == base_pool_liquidity, 0);
        assert!(base_balances.unclaimed_pool_fees == base_unclaimed_pool_fees, 0);
        assert!(base_balances.unclaimed_protocol_fees == base_unclaimed_protocol_fees, 0);
        let quote_balances = market_ref.quote_balances;
        assert!(quote_balances.book_liquidity == quote_book_liquidity, 0);
        assert!(quote_balances.pool_liquidity == quote_pool_liquidity, 0);
        assert!(quote_balances.unclaimed_pool_fees == quote_unclaimed_pool_fees, 0);
        assert!(quote_balances.unclaimed_protocol_fees == quote_unclaimed_protocol_fees, 0);
    }

    #[test_only]
    public fun assert_vault_values(
        market_address: address,
        base_expected: u64,
        quote_expected: u64,
    ) acquires Market {
        let market_ref = borrow_global<Market>(market_address);
        let metadata = market_ref.trading_pair.base_metadata;
        assert!(primary_fungible_store::balance(market_address, metadata) == base_expected, 0);
        metadata = market_ref.trading_pair.quote_metadata;
        assert!(primary_fungible_store::balance(market_address, metadata) == quote_expected, 0);
    }

    #[test_only]
    public fun assert_registry_parameters(
        registry_parameters: RegistryParameters,
        utility_asset_metadata_address: address,
        market_registration_fee: u64,
        oracle_fee: u64,
        integrator_withdrawal_fee: u64,
        book_map_inner_node_order: u16,
        book_map_leaf_node_order: u16,
        tick_map_inner_node_order: u16,
        tick_map_leaf_node_order: u16,
    ) {
        let utility_asset_metadata_address_to_check =
            object::object_address(&registry_parameters.utility_asset_metadata);
        assert!(utility_asset_metadata_address_to_check == utility_asset_metadata_address, 0);
        assert!(registry_parameters.market_registration_fee == market_registration_fee, 0);
        assert!(registry_parameters.oracle_fee == oracle_fee, 0);
        assert!(registry_parameters.integrator_withdrawal_fee == integrator_withdrawal_fee, 0);
        let node_orders = registry_parameters.book_map_node_orders;
        assert!(node_orders.inner_node_order == book_map_inner_node_order, 0);
        assert!(node_orders.leaf_node_order == book_map_leaf_node_order, 0);
        node_orders = registry_parameters.tick_map_node_orders;
        assert!(node_orders.inner_node_order == tick_map_inner_node_order, 0);
        assert!(node_orders.leaf_node_order == tick_map_leaf_node_order, 0);
    }

    #[test_only]
    public fun assert_open_orders_fields(
        open_orders_address: address,
        market_id: u64,
        trading_pair: TradingPair,
        market_address: address,
        user: address,
    ) acquires OpenOrders {
        let open_orders_ref = borrow_global<OpenOrders>(open_orders_address);
        assert!(open_orders_ref.market_id == market_id, 0);
        assert!(open_orders_ref.trading_pair == trading_pair, 0);
        assert!(open_orders_ref.market_address == market_address, 0);
        assert!(open_orders_ref.user == user, 0);
        assert!(open_orders_ref.open_orders_address == open_orders_address, 0);
    }

    #[test_only]
    public fun ensure_module_initialized_for_test() {
        let feature = features::get_coin_to_fungible_asset_migration_feature();
        features::change_feature_flags(&get_signer(@std), vector[feature], vector[]);
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
    public fun ensure_market_registered_for_test(): address acquires Registry, Status {
        ensure_module_initialized_for_test();
        let trading_pair = get_test_trading_pair();
        let registry_ref = borrow_global<Registry>(@econia);
        if (!table::contains(&registry_ref.trading_pair_market_ids, trading_pair)) {
            mint_fa_apt_to_market_registrant();
            let registrant = get_signer(MARKET_REGISTRANT_FOR_TEST);
            ensure_market_registered(
                &registrant,
                trading_pair.base_metadata,
                trading_pair.quote_metadata
            );
        };
        let registry_ref = borrow_global<Registry>(@econia);
        let market_address =
            table_with_length::borrow(&registry_ref.markets, MARKET_ID_FOR_TEST).market_address;
        market_address
    }

    #[test_only]
    public fun ensure_markets_registered_for_test() acquires Registry, Status  {
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
    public fun ensure_open_orders_registered_for_test(): (
        address,
        address
    ) acquires
        OpenOrdersByMarket,
        Registry,
        Status
    {
        let market_address = ensure_market_registered_for_test();
        let (base_metadata, quote_metadata) = test_assets::get_metadata();
        ensure_open_orders_registered(&get_signer(USER_FOR_TEST), base_metadata, quote_metadata);
        let open_orders_by_market_map_ref = &borrow_global<OpenOrdersByMarket>(USER_FOR_TEST).map;
        let open_orders_metadata_ref =
            smart_table::borrow(open_orders_by_market_map_ref, MARKET_ID_FOR_TEST);
        let open_orders_address = open_orders_metadata_ref.open_orders_address;
        (market_address, open_orders_address)
    }

    #[test_only]
    public fun get_signer(addr: address): signer { account::create_signer_for_test(addr) }

    #[test, expected_failure(abort_code = E_INACTIVE)]
    fun test_assert_active_status_inactive() acquires Status {
        ensure_module_initialized_for_test();
        set_status(&get_signer(@econia), false);
        assert_active_status();
    }

    #[test, expected_failure(abort_code = E_NOT_ECONIA)]
    fun test_set_status_not_econia() acquires Status { set_status(&get_signer(@0x0), false); }

    #[test, expected_failure(abort_code = E_NOT_ECONIA)]
    fun test_assert_signer_is_econia_not_econia() {
        assert_signer_is_econia(&get_signer(@0x0));
    }

    #[test, expected_failure(abort_code = E_OPTION_VECTOR_TOO_LONG)]
    fun test_assert_option_vector_is_valid_length_option_vector_too_long() {
        assert_option_vector_is_valid_length(&vector[0, 0]);
    }

    #[test, expected_failure(abort_code = E_NO_OPEN_ORDERS)]
    fun test_open_orders_exists_no_open_orders() {
        assert_open_orders_exists(@0x0);
    }

    #[test, expected_failure(abort_code = E_DOES_NOT_OWN_OPEN_ORDERS)]
    fun test_assert_open_orders_owner_does_not_own_open_orders()
    acquires
        OpenOrders,
        OpenOrdersByMarket,
        Registry,
        Status,
    {
        let (_, open_orders_address) = ensure_open_orders_registered_for_test();
        assert_open_orders_owner(borrow_global<OpenOrders>(open_orders_address), @0x0);
    }

    #[test]
    fun test_common_constants_rational() {
        assert!(COMPARE_EQUAL == rational::get_COMPARE_EQUAL(), 0);
        assert!(COMPARE_LEFT_GREATER == rational::get_COMPARE_LEFT_GREATER(), 0);
        assert!(COMPARE_RIGHT_GREATER == rational::get_COMPARE_RIGHT_GREATER(), 0);
    }

    #[test]
    fun test_open_orders_exists_and_correct_owner()
    acquires
        OpenOrders,
        OpenOrdersByMarket,
        Registry,
        Status,
    {
        let (_, open_orders_address) = ensure_open_orders_registered_for_test();
        assert_open_orders_exists(open_orders_address);
        assert_open_orders_owner(borrow_global<OpenOrders>(open_orders_address), USER_FOR_TEST);
    }

    #[test, expected_failure(abort_code = E_MARKET_NOT_COLLATERALIZED_BASE)]
    fun test_assert_market_fully_collateralized_market_not_collateralized_base()
    acquires Market, Registry, Status {
        let market_address = ensure_market_registered_for_test();
        let market_ref_mut = borrow_global_mut<Market>(market_address);
        market_ref_mut.base_balances.pool_liquidity = 1;
        assert_market_fully_collateralized(borrow_global<Market>(market_address));
    }

    #[test, expected_failure(abort_code = E_MARKET_NOT_COLLATERALIZED_QUOTE)]
    fun test_assert_market_fully_collateralized_market_not_collateralized_quote()
    acquires Market, Registry, Status {
        let market_address = ensure_market_registered_for_test();
        let market_ref_mut = borrow_global_mut<Market>(market_address);
        market_ref_mut.quote_balances.pool_liquidity = 1;
        assert_market_fully_collateralized(borrow_global<Market>(market_address));
    }

    #[test]
    fun test_socialize_withdrawal_amount() acquires Market, Registry, Status{
        let market_address = ensure_market_registered_for_test();
        let market_ref_mut = borrow_global_mut<Market>(market_address);
        assert!(socialize_withdrawal_amount(market_ref_mut, 0, true) == 0, 0);
        assert!(socialize_withdrawal_amount(market_ref_mut, 0, false) == 0, 0);
        market_ref_mut = borrow_global_mut<Market>(market_address);
        let balances_ref_mut = &mut market_ref_mut.base_balances;
        balances_ref_mut.book_liquidity = 10;
        balances_ref_mut.pool_liquidity = 20;
        balances_ref_mut = &mut market_ref_mut.quote_balances;
        balances_ref_mut.unclaimed_pool_fees = 12;
        balances_ref_mut.unclaimed_protocol_fees = 24;
        test_assets::mint(market_address, 30, 36);
        assert_market_fully_collateralized(market_ref_mut);
        assert!(socialize_withdrawal_amount(market_ref_mut, 5, true) == 5, 0);
        assert!(socialize_withdrawal_amount(market_ref_mut, 8, false) == 8, 0);
        test_assets::burn(market_address, 15, 12);
        assert!(socialize_withdrawal_amount(market_ref_mut, 10, true) == 5, 0);
        assert!(socialize_withdrawal_amount(market_ref_mut, 18, false) == 12, 0);
    }

    #[test, expected_failure(abort_code = E_WITHDRAWAL_EXCEEDS_EXPECTED_VAULT_BALANCE_BASE)]
    fun test_socialize_withdrawal_amount_withdrawal_exceeds_expected_vault_balance_base()
    acquires Market, Registry, Status {
        let market_address = ensure_market_registered_for_test();
        let market_ref = borrow_global<Market>(market_address);
        socialize_withdrawal_amount(market_ref, 10, true);
    }

    #[test, expected_failure(abort_code = E_WITHDRAWAL_EXCEEDS_EXPECTED_VAULT_BALANCE_QUOTE)]
    fun test_socialize_withdrawal_amount_withdrawal_exceeds_expected_vault_balance_quote()
    acquires Market, Registry, Status {
        let market_address = ensure_market_registered_for_test();
        let market_ref = borrow_global<Market>(market_address);
        socialize_withdrawal_amount(market_ref, 10, false);
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
    fun test_genesis_values() acquires Registry {
        ensure_module_initialized_for_test();
        let registry_ref = borrow_registry();
        assert_registry_parameters(
            registry_ref.registry_parameters,
            GENESIS_UTILITY_ASSET_METADATA_ADDRESS,
            GENESIS_MARKET_REGISTRATION_FEE,
            GENESIS_ORACLE_FEE,
            GENESIS_INTEGRATOR_WITHDRAWAL_FEE,
            GENESIS_BOOK_MAP_INNER_NODE_ORDER,
            GENESIS_BOOK_MAP_LEAF_NODE_ORDER,
            GENESIS_TICK_MAP_INNER_NODE_ORDER,
            GENESIS_TICK_MAP_LEAF_NODE_ORDER,
        );
        assert_market_parameters(
            registry_ref.default_market_parameters,
            GENESIS_DEFAULT_POOL_FEE_RATE,
            GENESIS_DEFAULT_PROTOCOL_FEE_RATE,
            GENESIS_DEFAULT_MAX_PRICE_SIG_FIGS,
            GENESIS_DEFAULT_EVICTION_TREE_HEIGHT,
            GENESIS_DEFAULT_EVICTION_PRICE_RATIO_ASK_NUMERATOR,
            GENESIS_DEFAULT_EVICTION_PRICE_RATIO_ASK_DENOMINATOR,
            GENESIS_DEFAULT_EVICTION_PRICE_RATIO_BID_NUMERATOR,
            GENESIS_DEFAULT_EVICTION_PRICE_RATIO_BID_DENOMINATOR,
            GENESIS_DEFAULT_EVICTION_LIQUIDITY_RATIO_NUMERATOR,
            GENESIS_DEFAULT_EVICTION_LIQUIDITY_RATIO_DENOMINATOR,
        );
    }

    #[test]
    fun test_ensure_market_registered() acquires Market, Registry, Status {
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
        assert!(market_ref.market_address == market_metadata.market_address, 0);
        assert!(market_ref.trading_pair == trading_pair, 0);
        assert!(market_ref.market_parameters == default_market_parameters, 0);
        assert_market_balances(market_ref.market_address, 0, 0, 0, 0, 0, 0, 0, 0);
        market_metadata = *table_with_length::borrow(&registry_ref.markets, 2);
        assert!(market_metadata.market_id == 2, 0);
        assert!(market_metadata.trading_pair == trading_pair_flipped, 0);
        assert!(market_metadata.market_parameters == default_market_parameters, 0);
        market_ref = borrow_global<Market>(market_metadata.market_address);
        assert!(market_ref.market_id == 2, 0);
        assert!(market_ref.market_address == market_metadata.market_address, 0);
        assert!(market_ref.trading_pair == trading_pair_flipped, 0);
        assert!(market_ref.market_parameters == default_market_parameters, 0);
        assert_market_balances(market_ref.market_address, 0, 0, 0, 0, 0, 0, 0, 0);
    }

    #[test, expected_failure(abort_code = E_NOT_ENOUGH_UTILITY_ASSET_TO_REGISTER_MARKET)]
    fun test_ensure_market_registered_not_enough_utility_asset() acquires Registry, Status {
        ensure_market_registered_for_test();
        let (base_metadata, quote_metadata) = test_assets::get_metadata();
        ensure_market_registered(
            &get_signer(MARKET_REGISTRANT_FOR_TEST),
            quote_metadata,
            base_metadata,
        );
    }

    #[test, expected_failure(abort_code = E_BASE_QUOTE_METADATA_SAME)]
    fun test_ensure_market_registered_base_quote_metadata_same() acquires Registry, Status {
        ensure_module_initialized_for_test();
        let (metadata, _) = test_assets::get_metadata();
        ensure_market_registered(&get_signer(MARKET_REGISTRANT_FOR_TEST), metadata, metadata);
    }

    #[test]
    fun test_ensure_open_orders_registered() acquires
        OpenOrders,
        OpenOrdersByMarket,
        Registry,
        Status
    {
        ensure_market_registered_for_test();
        let (base_metadata, quote_metadata) = test_assets::get_metadata();
        ensure_open_orders_registered(
            &get_signer(USER_FOR_TEST),
            base_metadata,
            quote_metadata
        );
        let registry = borrow_registry();
        let market_metadata = *table_with_length::borrow(&registry.markets, MARKET_ID_FOR_TEST);
        let trading_pair = market_metadata.trading_pair;
        let market_address = market_metadata.market_address;
        let open_orders_by_market_map_ref = &borrow_global<OpenOrdersByMarket>(USER_FOR_TEST).map;
        let open_orders_metadata =
            *smart_table::borrow(open_orders_by_market_map_ref, MARKET_ID_FOR_TEST);
        assert!(open_orders_metadata.market_id == MARKET_ID_FOR_TEST, 0);
        assert!(open_orders_metadata.trading_pair == trading_pair, 0);
        assert!(open_orders_metadata.market_address == market_address, 0);
        assert!(open_orders_metadata.user == USER_FOR_TEST, 0);
        assert_open_orders_fields(
            open_orders_metadata.open_orders_address,
            MARKET_ID_FOR_TEST,
            trading_pair,
            market_address,
            USER_FOR_TEST,
        );
        ensure_open_orders_registered(
            &get_signer(USER_FOR_TEST),
            base_metadata,
            quote_metadata
        );
    }

    #[test]
    fun test_update_recognized_markets() acquires Registry, Status {
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
        update_registry_parameters(
            &econia,
            vector[],
            vector[],
            vector[],
            vector[],
            vector[],
            vector[],
            vector[],
            vector[],
        );
        assert_registry_parameters(
            borrow_registry().registry_parameters,
            GENESIS_UTILITY_ASSET_METADATA_ADDRESS,
            GENESIS_MARKET_REGISTRATION_FEE,
            GENESIS_ORACLE_FEE,
            GENESIS_INTEGRATOR_WITHDRAWAL_FEE,
            GENESIS_BOOK_MAP_INNER_NODE_ORDER,
            GENESIS_BOOK_MAP_LEAF_NODE_ORDER,
            GENESIS_TICK_MAP_INNER_NODE_ORDER,
            GENESIS_TICK_MAP_LEAF_NODE_ORDER,
        );
        test_assets::ensure_assets_initialized();
        let (new_metadata, _) = test_assets::get_metadata();
        let new_metadata_address = object::object_address(&new_metadata);
        update_registry_parameters(
            &econia,
            vector[new_metadata_address],
            vector[1],
            vector[2],
            vector[3],
            vector[4],
            vector[5],
            vector[6],
            vector[7],
        );
        assert_registry_parameters(
            borrow_registry().registry_parameters,
            new_metadata_address,
            1,
            2,
            3,
            4,
            5,
            6,
            7
        );
    }

    #[test]
    fun test_update_market_parameters() acquires Market, Registry, Status {
        ensure_market_registered_for_test();
        let econia = get_signer(@econia);
        update_market_parameters(
            &econia,
            vector[1],
            vector[2],
            vector[3],
            vector[4],
            vector[5],
            vector[6],
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
            5,
            6,
            GENESIS_DEFAULT_EVICTION_PRICE_RATIO_ASK_DENOMINATOR,
            GENESIS_DEFAULT_EVICTION_PRICE_RATIO_BID_NUMERATOR,
            GENESIS_DEFAULT_EVICTION_PRICE_RATIO_BID_DENOMINATOR,
            GENESIS_DEFAULT_EVICTION_LIQUIDITY_RATIO_NUMERATOR,
            GENESIS_DEFAULT_EVICTION_LIQUIDITY_RATIO_DENOMINATOR,
        );
        update_market_parameters(
            &econia,
            vector[],
            vector[],
            vector[],
            vector[],
            vector[],
            vector[],
            vector[7],
            vector[8],
            vector[9],
            vector[10],
            vector[11],
        );
        assert_market_parameters(
            borrow_registry().default_market_parameters,
            GENESIS_DEFAULT_POOL_FEE_RATE,
            GENESIS_DEFAULT_PROTOCOL_FEE_RATE,
            GENESIS_DEFAULT_MAX_PRICE_SIG_FIGS,
            GENESIS_DEFAULT_EVICTION_TREE_HEIGHT,
            GENESIS_DEFAULT_EVICTION_PRICE_RATIO_ASK_NUMERATOR,
            7,
            8,
            9,
            10,
            11,
        )
    }

    #[test, expected_failure(abort_code = E_INVALID_MARKET_ID)]
    fun test_update_market_parameters_invalid_market_id() acquires Market, Registry, Status {
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
            vector[],
        );
    }

}
