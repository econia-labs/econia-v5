module research::structs {

    use aptos_framework::table::Table;

    struct Ratio has copy, drop {
        numerator: u64,
        denominator: u64,
    }

    /// An NFT.
    struct Position {
        base_in: u64,
        quote_in: u64,
        /// Q128.128, representing virtual base in pool at time of contribution.
        virtual_base_start: u256,
        /// Q128.128, representing virtual quote in pool at time of contribution.
        virtual_quote_start: u256,
        lower_price_bound: Ratio,
        upper_price_bound: Ratio,
    }

    struct Tick {
        price: Ratio,
        /// Q128.128.
        virtual_base_net: u256,
        virtual_base_net_is_positive: bool,
        /// Q128.128.
        virtual_quote_net: u256,
        virtual_quote_net_is_positive: bool,
        /// When 0, tick can be closed.
        n_referencing_positions: u64,
        base_growth_outside: u64,
        quote_growth_outside: u64,
    }

    struct Pool {
        /// Q128.128
        virtual_base: u256,
        /// Q128.128
        virtual_quote: u256,
        /// Should be a sorted, iterable map from price to tick.
        ticks: Table<Ratio, Tick>,
        base_growth_global: u64,
        quote_growth_global: u64,
        /// For full-range positions.
        issued_lp_tokens: u64,
        lp_tokens_base_in: u64,
        lp_tokens_quote_in: u64,
        lp_tokens_virtual_base_last: u64,
        lp_tokens_virtual_quote_last: u64,
    }

}