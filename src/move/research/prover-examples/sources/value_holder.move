module prover_examples::value_holder {
    use std::signer;

    const DEFAULT_VALUE: u8 = 0;

    struct ValueHolder has key {
        value: u8
    }

    struct ValueHolderManifest has key {
        /// The addresses of all accounts that have a ValueHolder.
        account_addresses: vector<address>,
        /// The value that all ValueHolders should have.
        value: u8
    }

    spec ValueHolderManifest {
        // Prohibit account address duplicates in the manifest.
        invariant forall account_address: address where contains(
            account_addresses, account_address
        ):
            {
                let index = index_of(account_addresses, account_address);
                let length = len(account_addresses);
                let before =
                    if (index == 0) { vec() }
                    else {
                        account_addresses[0..index]
                    };
                let after =
                    if (index == length - 1) { vec() }
                    else {
                        account_addresses[index + 1..length]
                    };
                let without = concat(before, after);
                contains(without, account_address) == false
            };
    }

    spec schema Initialized {
        requires exists<ValueHolderManifest>(@prover_examples);
    }

    spec module {
        apply Initialized to * except init_module;
    }

    /// Ensure that the manifest only exists at the publisher address.
    invariant forall account_address: address where account_address != @prover_examples:
        !exists<ValueHolderManifest>(account_address);

    /// Ensure that for every value holder, there is a corresponding account address in the
    /// manifest and that the value in the holder is the same as the value in the manifest.
    invariant [suspendable] forall account_address: address where exists<ValueHolder>(
        account_address
    ):
        exists<ValueHolderManifest>(@prover_examples)
            && contains(
                global<ValueHolderManifest>(@prover_examples).account_addresses,
                account_address
            )
            && global<ValueHolder>(account_address).value
                == global<ValueHolderManifest>(@prover_examples).value;

    /// Ensure that for every account address in the manifest, there exists a corresponding
    /// holder and that the value inside it is the same as the value in the manifest.
    invariant [suspendable] forall account_address: address where contains(
        global<ValueHolderManifest>(@prover_examples).account_addresses,
        account_address
    ):
        exists<ValueHolder>(account_address)
            && global<ValueHolder>(account_address).value
                == global<ValueHolderManifest>(@prover_examples).value;

    /// Ensure that on the creation of a value holder, the account address is originally absent
    /// from the manifest then gets added, and that the value in the value holder is the same as
    /// the value in the manifest.
    invariant update[suspendable] forall account_address: address where !old(
        exists<ValueHolder>(account_address)
    ) && exists<ValueHolder>(account_address):
        contains(
            global<ValueHolderManifest>(@prover_examples).account_addresses,
            account_address
        )
            && old(
                !contains(
                    global<ValueHolderManifest>(@prover_examples).account_addresses,
                    account_address
                )
            )
            && global<ValueHolder>(account_address).value
                == global<ValueHolderManifest>(@prover_examples).value;

    /// Ensure that if an account address is originally absent from the manifest but is then
    /// added, a value holder is created at the corresponding address with the correct value.
    invariant update[suspendable] forall account_address: address where !old(
        contains(
            global<ValueHolderManifest>(@prover_examples).account_addresses,
            account_address
        )
    ) && contains(
        global<ValueHolderManifest>(@prover_examples).account_addresses,
        account_address
    ):
        exists<ValueHolder>(account_address)
            && old(!exists<ValueHolder>(account_address))
            && global<ValueHolder>(account_address).value
                == global<ValueHolderManifest>(@prover_examples).value;

    /// Ensure that if the value in the manifest is updated, all value holders are updated.
    invariant update[suspendable] forall new_value: u8, account_address: address where old(
        exists<ValueHolderManifest>(@prover_examples)
    )
        && old(exists<ValueHolder>(account_address))
        && old(global<ValueHolderManifest>(@prover_examples).value) != new_value
        && global<ValueHolderManifest>(@prover_examples).value == new_value:
        old(global<ValueHolder>(account_address).value) != new_value
            && global<ValueHolder>(account_address).value == new_value;

    public fun init_value_holder(account: &signer) acquires ValueHolderManifest {
        let value_holder_manifest_ref_mut = &mut ValueHolderManifest[@prover_examples];
        move_to(
            account,
            ValueHolder { value: value_holder_manifest_ref_mut.value }
        );
        value_holder_manifest_ref_mut.account_addresses.push_back(
            signer::address_of(account)
        );
    }

    public fun update_value(new_value: u8) acquires ValueHolder, ValueHolderManifest {
        // Update value in the manifest, returning early if no update.
        let value_holder_manifest_ref_mut = &mut ValueHolderManifest[@prover_examples];
        let value_ref_mut = &mut value_holder_manifest_ref_mut.value;
        if (*value_ref_mut == new_value) return;
        value_holder_manifest_ref_mut.value = new_value;

        // Update value in all value holders.
        let account_addresses_ref = &value_holder_manifest_ref_mut.account_addresses;
        let index = 0;
        let n_addresses = account_addresses_ref.length();
        while ({
            spec {
                invariant forall i: u64 where i < index:
                    global<ValueHolder>(account_addresses_ref[i]).value
                        == global<ValueHolderManifest>(@prover_examples).value;
            };
            index < n_addresses
        }) {
            ValueHolder[account_addresses_ref[index]].value = new_value;
            spec {
                assert ValueHolder[account_addresses_ref[index]].value == new_value;
            };
            index = index + 1;
        };
    }

    fun init_module(prover_examples: &signer) {
        move_to(
            prover_examples,
            ValueHolderManifest { account_addresses: vector[], value: DEFAULT_VALUE }
        );
    }

    spec init_module {
        requires signer::address_of(prover_examples) == @prover_examples;
        ensures old(!exists<ValueHolderManifest>(@prover_examples));
        ensures exists<ValueHolderManifest>(@prover_examples);
        ensures global<ValueHolderManifest>(signer::address_of(prover_examples))
            == ValueHolderManifest { account_addresses: vector[], value: DEFAULT_VALUE };
    }

    spec init_value_holder {
        pragma disable_invariants_in_body;

        // Require that the account address is not already in the manifest and that no value holder
        // exists at the account address.
        let account_address = signer::address_of(account);
        requires !contains(
            global<ValueHolderManifest>(@prover_examples).account_addresses,
            account_address
        );
        requires !exists<ValueHolder>(account_address);

        // Verify value holder creation.
        aborts_if exists<ValueHolder>(account_address);
        ensures exists<ValueHolder>(account_address);
        ensures global<ValueHolder>(account_address).value
            == global<ValueHolderManifest>(@prover_examples).value;

        // Verify that the account address is added to the manifest.
        modifies global<ValueHolderManifest>(@prover_examples);
        ensures !contains(
            old(global<ValueHolderManifest>(@prover_examples).account_addresses),
            account_address
        );
        ensures contains(
            global<ValueHolderManifest>(@prover_examples).account_addresses,
            account_address
        );
    }

    spec update_value {
        pragma disable_invariants_in_body;

        // Ensure manifest value is updated.
        ensures global<ValueHolderManifest>(@prover_examples).value == new_value;

        // Ensure all value holders in the manifest have the new value.
        ensures forall account_address: address where contains(
            global<ValueHolderManifest>(@prover_examples).account_addresses,
            account_address
        ): global<ValueHolder>(account_address).value == new_value;

        // Ensure all holders that exist have the new value.
        ensures forall account_address: address where exists<ValueHolder>(
            account_address
        ): global<ValueHolder>(account_address).value == new_value;
    }
}
