module econia::rational {

    friend econia::core;

    const SHIFT_NUMERATOR: u8 = 64;
    const HI_64_u128: u128 = 0xffffffffffffffff;

    const COMPARE_LEFT_GREATER: u8 = 0;
    const COMPARE_RIGHT_GREATER: u8 = 1;
    const COMPARE_EQUAL: u8 = 2;

    public(friend) inline fun encode(numerator: u64, denominator: u64): u128 {
        (numerator as u128) << SHIFT_NUMERATOR | (denominator as u128)
    }

    public(friend) inline fun decode(encoded: u128): (u64, u64) {
        ((encoded >> SHIFT_NUMERATOR as u64), (encoded & HI_64_u128 as u64))
    }

    public(friend) inline fun compare_unchecked(
        left_numerator: u64,
        left_denominator: u64,
        right_numerator: u64,
        right_denominator: u64
    ): u8 {
        let (a, b) = (
            (left_numerator as u128) * (right_denominator as u128),
            (right_numerator as u128) * (left_denominator as u128),
        );
        if (a > b) COMPARE_LEFT_GREATER else if (a < b) COMPARE_RIGHT_GREATER else COMPARE_EQUAL
    }

    #[test_only]
    public(friend) fun get_COMPARE_LEFT_GREATER(): u8 { COMPARE_LEFT_GREATER }

    #[test_only]
    public(friend) fun get_COMPARE_RIGHT_GREATER(): u8 { COMPARE_RIGHT_GREATER }

    #[test_only]
    public(friend) fun get_COMPARE_EQUAL(): u8 { COMPARE_EQUAL }

    #[test]
    fun test_encode_decode() {
        let numerator = 5;
        let denominator = 64;
        let encoded = encode(numerator, denominator);
        let (numerator_decoded, denominator_decoded) = decode(encoded);
        assert!(numerator == numerator_decoded, 0);
        assert!(denominator == denominator_decoded, 0);
    }

    #[test]
    fun test_compare_unchecked() {
        assert!(compare_unchecked(1, 5, 2, 10) == COMPARE_EQUAL, 0);
        assert!(compare_unchecked(1, 4, 1, 5) == COMPARE_LEFT_GREATER, 0);
        assert!(compare_unchecked(1, 5, 1, 4) == COMPARE_RIGHT_GREATER, 0);
    }
}
