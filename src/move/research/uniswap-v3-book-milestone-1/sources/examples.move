module research::examples {

    const SHIFT_Q64: u8 = 64;

    use aptos_std::debug;
    use aptos_std::string_utils;
    use std::string;

    #[test_only]
    use research::math;

    fun print_labeled_value<T: drop>(label: vector<u8>, value: T) {
        let msg = string::utf8(label);
        string::append(&mut msg, string::utf8(b": "));
        string::append(&mut msg, string_utils::debug_string(&value));
        debug::print(&msg);
    }

    #[test]
    fun calculating_liquidity() {
        let current_nominal_price = 5000;
        let sqrt_p_l = math::sqrt_q64(math::u64_to_q64(4545));
        let sqrt_p_c = math::sqrt_q64(math::u64_to_q64(current_nominal_price));
        let sqrt_p_u = math::sqrt_q64(math::u64_to_q64(5500));
        print_labeled_value(b"Root P_l as Q64", sqrt_p_l);
        print_labeled_value(b"Root P_c as Q64", sqrt_p_c);
        print_labeled_value(b"Root P_u as Q64", sqrt_p_u);
        let sqrt_p_b = sqrt_p_u;
        let sqrt_p_a = sqrt_p_l;
        let delta_base = 1_000_000;
        let delta_quote = delta_base * current_nominal_price;
        let liquidity_base = math::divide_q64_unchecked(
            math::multiply_q64_unchecked(
                math::u64_to_q64(delta_base),
                math::multiply_q64_unchecked(sqrt_p_b, sqrt_p_c),
            ),
            math::subtract_q64_unchecked(sqrt_p_b, sqrt_p_c),
        );
        let liquidity_quote = math::divide_q64_unchecked(
            math::u64_to_q64(delta_quote),
            math::subtract_q64_unchecked(sqrt_p_c, sqrt_p_a),
        );
        print_labeled_value(b"Liquidity (base)", liquidity_base);
        print_labeled_value(b"Liquidity (quote)", liquidity_quote);
        assert!(liquidity_quote < liquidity_base, 0);
        debug::print(&string::utf8(b"Using liquidity (quote)"));
        let liquidity = liquidity_quote;
        let delta_base_actual = math::q64_to_u64(
            math::divide_q64_unchecked(
                math::multiply_q64_unchecked(
                    liquidity,
                    math::subtract_q64_unchecked(sqrt_p_b, sqrt_p_c),
                ),
                math::multiply_q64_unchecked(sqrt_p_b, sqrt_p_c)
            )
        );
        let delta_quote_actual = math::q64_to_u64(
            math::multiply_q64_unchecked(
                liquidity,
                math::subtract_q64_unchecked(sqrt_p_c, sqrt_p_a),
            )
        );
        print_labeled_value(b"Delta base", delta_base_actual);
        print_labeled_value(b"Delta quote", delta_quote_actual);
    }

    #[test]
    fun first_swap() {
        let quote_amount = 42_000_000;
        let sqrt_p_c = math::sqrt_q64(math::u64_to_q64(5000));
        let liquidity = 27999987129186539257502108059; // From `calculating_liquidity`.
        let delta_sqrt_p = math::divide_q64_unchecked(math::u64_to_q64(quote_amount), liquidity);
        let target_sqrt_p = math::add_q64_unchecked(sqrt_p_c, delta_sqrt_p);
        print_labeled_value(b"Target root price as Q64", target_sqrt_p);
        let delta_base = math::q64_to_u64(
            math::subtract_q64_unchecked(
                math::divide_q64_unchecked(
                    liquidity,
                    sqrt_p_c,
                ),
                math::divide_q64_unchecked(
                    liquidity,
                    target_sqrt_p,
                ),
            )
        );
        print_labeled_value(b"Delta base", delta_base);
    }
}
