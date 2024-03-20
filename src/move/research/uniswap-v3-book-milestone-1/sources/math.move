// cspell:words stdlib
module code::math {

    const SHIFT_Q64: u8 = 64;

    inline fun sqrt(i: u256): u256 {
        if (i <= 1) {
            i
        } else {
            let estimate = 1 << ((log2_unchecked(i) / 2) + 1);
            let update;
            loop {
                update = (estimate + i / estimate) / 2;
                if (update >= estimate) break;
                estimate = update;
            };
            estimate
        }
    }

    /// Does not check for case of `i` = 0, which is undefined.
    inline fun log2_unchecked(i: u256): u8 {
        let result = 0;
        let check_bit = 128;
        loop {
            if (i >= (1 << check_bit)) {
                i = i >> check_bit;
                result = result + check_bit;
            };
            check_bit = check_bit / 2;
            if (check_bit == 0) break
        };
        result
    }

    inline fun u64_to_q64(x: u64): u128 { (x as u128) << SHIFT_Q64 }

    inline fun q64_to_u64(x: u128): u64 { ((x >> SHIFT_Q64) as u64) }

    inline fun sqrt_q64(x: u128): u128 { (sqrt((x as u256) << SHIFT_Q64) as u128) }

    /// Does not check for overflow.
    inline fun multiply_q64_unchecked(a: u128, b: u128): u128 {
        ((((a as u256) * (b as u256)) >> SHIFT_Q64) as u128)
    }

    /// Does not check for overflow or divide by zero.
    inline fun divide_q64_unchecked(a: u128, b: u128): u128 {
        (((a as u256) << SHIFT_Q64) / (b as u256) as u128)
    }

    /// Does not check for overflow.
    inline fun add_q64_unchecked(a: u128, b: u128): u128 { a + b }

    /// Does not check for underflow.
    inline fun subtract_q64_unchecked(a: u128, b: u128): u128 { a - b }

    #[test]
    /// Adapted from `aptos_stdlib::math128`.
    fun test_log2_unchecked() {
        let bit = 255;
        while (bit > 0) {
            let operand = (1 << bit) + 1;
            assert!(log2_unchecked(operand) == bit, 0);
            bit = bit - 1;
        };
        assert!(log2_unchecked(1) == 0, 0);
    }

    #[test]
    fun test_sqrt() {
        assert!(sqrt(1) == 1, 0);
        assert!(sqrt(10) == 3, 0);
        assert!(sqrt(5000) == 70, 0); // From Uni v3 book example.
        assert!(sqrt(4545) == 67, 0); // From Uni v3 book example.
        assert!(sqrt(5500) == 74, 0); // From Uni v3 book example.
        assert!(sqrt(2000000) == 1414, 0); // From Wikipedia example.
    }

    #[test]
    fun test_q64_math() {
        assert!(q64_to_u64(u64_to_q64(25)) == 25, 0);
        assert!(sqrt_q64(u64_to_q64(4)) == u64_to_q64(2), 0);
        let a = u64_to_q64(12);
        let b = u64_to_q64(6);
        assert!(multiply_q64_unchecked(a, b) == u64_to_q64(72), 0);
        assert!(divide_q64_unchecked(a, b) == u64_to_q64(2), 0);
        assert!(add_q64_unchecked(a, b) == u64_to_q64(18), 0);
        assert!(subtract_q64_unchecked(a, b) == b, 0);
    }

}
