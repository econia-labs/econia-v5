// cspell:words stdlib
module math::math {

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
}
