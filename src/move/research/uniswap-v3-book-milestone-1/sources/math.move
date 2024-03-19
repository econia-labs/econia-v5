module math::math {

    inline fun sqrt(s: u256): u256 {
        if (s <= 1) return s
        let estimate = s / 2;
        let
    }

    /// Does not check for case of `i` = 0, which is undefined.
    inline fun log2_unchecked(i: u256): u256 {
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
        (result as u256)
    }


    #[test]
    fun test_log2_unchecked() {
        let bit = 255;
        while (bit > 0) {
            let operand = (1 << bit) + 1;
            assert!(log2_unchecked(operand) == (bit as u256), 0);
            bit = bit - 1;
        };
        assert!(log2_unchecked(1) == 0, 0);
    }
}
