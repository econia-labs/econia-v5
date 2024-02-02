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
    const GENESIS_DEFAULT_POOL_FEE_RATE_NUMERATOR: u64 = 30;
    const GENESIS_DEFAULT_POOL_FEE_RATE_DENOMINATOR: u64 = 10_000;
    const GENESIS_DEFAULT_TAKER_FEE_RATE_NUMERATOR: u64 = 0;
    const GENESIS_DEFAULT_TAKER_FEE_RATE_DENOMINATOR: u64 = 10_000;
    const GENESIS_BASELINE_FEE_RATE_NUMERATOR: u64 = 10;
    const GENESIS_BASELINE_FEE_RATE_DENOMINATOR: u64 = 10_000;

    /// Registrant's utility asset primary fungible store balance is below market registration fee.
    const E_NOT_ENOUGH_UTILITY_ASSET_TO_REGISTER_MARKET: u64 = 0;
    /// The given trading pair already exists for the specified size parameters.
    const E_SIZED_PAIR_ALREADY_REGISTERED: u64 = 1;
    /// The lot size is specified as 0.
    const E_LOT_SIZE_0: u64 = 2;
    /// The tick size is specified as 0.
    const E_TICK_SIZE_0: u64 = 3;
    /// The minimum post size is specified as 0.
    const E_MIN_POST_SIZE_0: u64 = 4;
    /// Pool fee rate may result in fee truncation for given size parameters.
    const E_POOL_FEES_MAY_TRUNCATE: u64 = 5;
    /// Taker fee rate may result in fee truncation for given size parameters.
    const E_TAKER_FEES_MAY_TRUNCATE: u64 = 6;
    /// Fees may truncate for the baseline fee rate.
    const E_BASELINE_FEE_RATE_MAY_TRUNCATE: u64 = 7;
    /// Default pool fee rate is an invalid fee rate.
    const E_DEFAULT_POOL_FEE_RATE_INVALID: u64 = 8;
    /// Default taker fee rate is an invalid fee rate.
    const E_DEFAULT_TAKER_FEE_RATE_INVALID: u64 = 9;
    /// Baseline fee rate is an invalid fee rate.
    const E_BASELINE_FEE_RATE_INVALID: u64 = 10;
    /// Pool fee rate is not a round multiple of baseline fee rate.
    const E_POOL_FEE_RATE_NOT_MULTIPLE_OF_BASELINE: u64 = 11;
    /// Taker fee rate is not a round multiple of baseline fee rate.
    const E_TAKER_FEE_RATE_NOT_MULTIPLE_OF_BASELINE: u64 = 12;

    #[resource_group_member(group = ObjectGroup)]
    struct Market has key {
        market_id: u64,
        sized_pair: SizedPair,
        market_fee_rates: MarketFeeRates,
    }

    struct MarketMetadata has copy, store {
        market_id: u64,
        market_object: Object<Market>,
        sized_pair: SizedPair,
        market_fee_rates: MarketFeeRates,
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
        sized_pairs: Table<SizedPair, u64>,
        recognized_markets: Table<TradingPair, u64>,
        utility_asset_metadata: Object<Metadata>,
        market_registration_fee: u64,
        default_market_fee_rates: MarketFeeRates,
        baseline_fee_rate: FeeRate,
    }

    struct FeeRate has copy, drop, store {
        numerator: u64,
        denominator: u64,
    }

    struct MarketFeeRates has copy, drop, store {
        pool_fee_rate: FeeRate,
        taker_fee_rate: FeeRate,
    }

    struct SizeParameters has copy, drop, store {
        lot_size: u64,
        tick_size: u64,
        min_post_size: u64,
    }

    struct SizedPair has copy, drop, store {
        trading_pair: TradingPair,
        size_parameters: SizeParameters,
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
            E_NOT_ENOUGH_UTILITY_ASSET_TO_REGISTER_MARKET,
        );
        primary_fungible_store::transfer(
            registrant,
            utility_asset_metadata,
            @econia,
            market_registration_fee,
        );
        assert!(lot_size != 0, E_LOT_SIZE_0);
        assert!(tick_size != 0, E_TICK_SIZE_0);
        assert!(min_post_size != 0, E_MIN_POST_SIZE_0);
        let trading_pair = TradingPair { base_metadata, quote_metadata };
        let size_parameters = SizeParameters { lot_size, tick_size, min_post_size };
        let sized_pair = SizedPair { trading_pair, size_parameters };
        let sized_pairs_ref_mut = &mut registry_ref_mut.sized_pairs;
        assert!(
            !table::contains(sized_pairs_ref_mut, sized_pair),
            E_SIZED_PAIR_ALREADY_REGISTERED,
        );
        let markets_ref_mut = &mut registry_ref_mut.markets;
        let market_id = table_with_length::length(markets_ref_mut);
        let constructor_ref = object::create_object(@econia);
        let market_object = object::object_from_constructor_ref(&constructor_ref);
        let market_fee_rates = registry_ref_mut.default_market_fee_rates;
        let pool_fee_rate = market_fee_rates.pool_fee_rate;
        let pool_fees_may_truncate = fees_may_truncate(pool_fee_rate, size_parameters);
        assert!(!pool_fees_may_truncate, E_POOL_FEES_MAY_TRUNCATE);
        let taker_fee_rate = market_fee_rates.taker_fee_rate;
        let taker_fees_may_truncate = fees_may_truncate(taker_fee_rate, size_parameters);
        assert!(!taker_fees_may_truncate, E_TAKER_FEES_MAY_TRUNCATE);
        let baseline_fee_rate = registry_ref_mut.baseline_fee_rate;
        let baseline_fees_may_truncate = fees_may_truncate(baseline_fee_rate, size_parameters);
        assert!(!baseline_fees_may_truncate, E_BASELINE_FEE_RATE_MAY_TRUNCATE);
        let market_metadata = MarketMetadata {
            market_id,
            market_object,
            sized_pair,
            market_fee_rates,
        };
        let market_signer = object::generate_signer(&constructor_ref);
        move_to(&market_signer, Market {
            market_id,
            sized_pair,
            market_fee_rates,
        });
        table_with_length::add(markets_ref_mut, market_id, market_metadata);
        table::add(sized_pairs_ref_mut, sized_pair, market_id);
    }

    fun check_fee_defaults(
        default_pool_fee_rate: FeeRate,
        default_taker_fee_rate: FeeRate,
        baseline_fee_rate: FeeRate,
    ) {
        assert!(is_valid_fee_rate(default_pool_fee_rate), E_DEFAULT_POOL_FEE_RATE_INVALID);
        assert!(is_valid_fee_rate(default_taker_fee_rate), E_DEFAULT_TAKER_FEE_RATE_INVALID);
        assert!(is_valid_fee_rate(baseline_fee_rate), E_BASELINE_FEE_RATE_INVALID);
        if (default_pool_fee_rate.numerator != 0) {
            assert!(
                fee_rate_is_multiple_of(default_pool_fee_rate, baseline_fee_rate),
                E_POOL_FEE_RATE_NOT_MULTIPLE_OF_BASELINE,
            );
        };
        if (default_taker_fee_rate.numerator != 0) {
            assert!(
                fee_rate_is_multiple_of(default_taker_fee_rate, baseline_fee_rate),
                E_TAKER_FEE_RATE_NOT_MULTIPLE_OF_BASELINE,
            );
        };
    }

    fun fees_may_truncate(
        fee_rate: FeeRate,
        size_parameters: SizeParameters,
    ): bool {
        let n = (fee_rate.numerator as u128);
        let d = (fee_rate.denominator as u128);
        let lot_size = (size_parameters.lot_size as u128);
        let tick_size = (size_parameters.tick_size as u128);
        (n * lot_size) % d != 0 || (n * tick_size) % d != 0
    }

    fun fee_rate_is_multiple_of(
        to_check: FeeRate,
        baseline: FeeRate,
    ): bool {
        let (c_n, c_d) = ((to_check.numerator as u128), (to_check.denominator as u128));
        let (b_n, b_d) = ((baseline.numerator as u128), (baseline.denominator as u128));
        (c_n * b_d) % (b_n * c_d) == 0
    }

    fun init_module_internal(
        econia: &signer,
        utility_asset_metadata: Object<Metadata>
    ) {
        move_to(econia, Registry {
            markets: table_with_length::new(),
            sized_pairs: table::new(),
            recognized_markets: table::new(),
            utility_asset_metadata,
            market_registration_fee: GENESIS_MARKET_REGISTRATION_FEE,
            default_market_fee_rates: MarketFeeRates {
                pool_fee_rate: FeeRate {
                    numerator: GENESIS_DEFAULT_POOL_FEE_RATE_NUMERATOR,
                    denominator: GENESIS_DEFAULT_POOL_FEE_RATE_DENOMINATOR,
                },
                taker_fee_rate: FeeRate {
                    numerator: GENESIS_DEFAULT_TAKER_FEE_RATE_NUMERATOR,
                    denominator: GENESIS_DEFAULT_TAKER_FEE_RATE_DENOMINATOR,
                },
            },
            baseline_fee_rate: FeeRate {
                numerator: GENESIS_BASELINE_FEE_RATE_NUMERATOR,
                denominator: GENESIS_BASELINE_FEE_RATE_DENOMINATOR,
            },
        });
    }

    fun is_valid_fee_rate(
        fee_rate: FeeRate
    ): bool {
        fee_rate.numerator < fee_rate.denominator && fee_rate.denominator != 0
    }

    #[test_only]
    public fun init_module_test() {
        let (_, quote_asset) = test_assets::get_metadata();
        init_module_internal(&account::create_signer_for_test(@econia), quote_asset);
    }

    #[test]
    fun test_fees_may_truncate() {
        let ten_basis_points = FeeRate { numerator: 10, denominator: 10_000 };
        assert!(
            !fees_may_truncate(
                ten_basis_points,
                SizeParameters { lot_size: 1000, tick_size: 1000, min_post_size: 1 }
            ),
        0);
        assert!(
            fees_may_truncate(
                ten_basis_points,
                SizeParameters { lot_size: 1001, tick_size: 1000, min_post_size: 1 }
            ),
        0);
        assert!(
            fees_may_truncate(
                ten_basis_points,
                SizeParameters { lot_size: 1000, tick_size: 1001, min_post_size: 1 }
            ),
        0);
    }

    #[test]
    fun test_genesis_fee_values() acquires Registry {
        init_module_test();
        let registry_ref_mut = borrow_global_mut<Registry>(@econia);
        let pool_fee_rate = registry_ref_mut.default_market_fee_rates.pool_fee_rate;
        let taker_fee_rate = registry_ref_mut.default_market_fee_rates.taker_fee_rate;
        let baseline_fee_rate = registry_ref_mut.baseline_fee_rate;
        check_fee_defaults(pool_fee_rate, taker_fee_rate, baseline_fee_rate);
    }
}
