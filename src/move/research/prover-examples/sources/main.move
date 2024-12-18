module prover_examples::main {

    use std::signer;

    const MAX_VALUE: u8 = 100;

    /// The provided value is too high.
    const E_VALUE_TOO_HIGH: u64 = 0;

    struct PhantomKeyStruct<phantom T> has key {
        account_address: address,
        value: u8
    }

    spec PhantomKeyStruct {
        invariant value <= MAX_VALUE;
    }

    invariant<T> forall account_address: address where exists<PhantomKeyStruct<T>>(
        account_address
    ): global<PhantomKeyStruct<T>>(account_address).account_address == account_address;

    public fun move_to_phantom_key_struct<T>(account: &signer, value: u8) {
        assert!(value <= MAX_VALUE, E_VALUE_TOO_HIGH);
        move_to(
            account,
            PhantomKeyStruct<T> { account_address: signer::address_of(account), value }
        );
    }

    public fun increment_phantom_key_struct_with_rollover<T>(
        account: &signer
    ) acquires PhantomKeyStruct<T> {
        let value_ref_mut = &mut PhantomKeyStruct<T>[signer::address_of(account)].value;
        if (*value_ref_mut == MAX_VALUE) {
            *value_ref_mut = 0;
        } else {
            *value_ref_mut = *value_ref_mut + 1;
        };
    }

    spec move_to_phantom_key_struct {
        aborts_if value > MAX_VALUE;
        aborts_if exists_phantom_key_struct<T>(account);
        ensures exists_phantom_key_struct<T>(account);
        ensures global<PhantomKeyStruct<T>>(signer::address_of(account))
            == PhantomKeyStruct<T> { account_address: signer::address_of(account), value };
    }

    spec fun exists_phantom_key_struct<T>(account: &signer): bool {
        exists<PhantomKeyStruct<T>>(signer::address_of(account))
    }
}
