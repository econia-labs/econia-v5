module prover_examples::phantom_key_struct {

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

    // Ensure that wherever a PhantomKeyStruct<T> exists, the account_address field is equal to the
    // account address of the struct.
    invariant<T> forall account_address: address where exists<PhantomKeyStruct<T>>(
        account_address
    ): global<PhantomKeyStruct<T>>(account_address).account_address == account_address;

    // Ensure that on update to an individual PhantomKeyStruct<T>, the value field is incremented by
    // 1, or reset to 0 if it was already at MAX_VALUE.
    invariant<T> update[global] forall account_address: address where exists<
        PhantomKeyStruct<T>>(account_address)
        && old(
            exists<PhantomKeyStruct<T>>(account_address)
        )
        && global<PhantomKeyStruct<T>>(account_address).value
            != old(
                global<PhantomKeyStruct<T>>(account_address).value
            ):
        global<PhantomKeyStruct<T>>(account_address).value
            == old(
                global<PhantomKeyStruct<T>>(account_address).value
            ) + 1
            || (
                global<PhantomKeyStruct<T>>(account_address).value == 0
                    && old(
                        global<PhantomKeyStruct<T>>(account_address).value
                    ) == MAX_VALUE
            );

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

    spec increment_phantom_key_struct_with_rollover {
        aborts_if !exists_phantom_key_struct<T>(account);
        ensures exists_phantom_key_struct<T>(account);
        let account_address = signer::address_of(account);
        modifies global<PhantomKeyStruct<T>>(account_address);
        ensures global<PhantomKeyStruct<T>>(account_address).value
            == old(
                global<PhantomKeyStruct<T>>(account_address).value
            ) + 1
            || (
                global<PhantomKeyStruct<T>>(account_address).value == 0
                    && old(
                        global<PhantomKeyStruct<T>>(account_address).value
                    ) == MAX_VALUE
            );
    }

    spec move_to_phantom_key_struct {
        aborts_if value > MAX_VALUE with E_VALUE_TOO_HIGH;
        aborts_if exists_phantom_key_struct<T>(account);
        ensures exists_phantom_key_struct<T>(account);
        ensures global<PhantomKeyStruct<T>>(signer::address_of(account))
            == PhantomKeyStruct<T> { account_address: signer::address_of(account), value };
    }

    spec fun exists_phantom_key_struct<T>(account: &signer): bool {
        exists<PhantomKeyStruct<T>>(signer::address_of(account))
    }
}
