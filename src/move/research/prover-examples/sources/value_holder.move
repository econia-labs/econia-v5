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

    spec schema Initialized {
        aborts_if !exists<ValueHolderManifest>(@prover_examples);
    }

    spec module {
        apply Initialized to * except init_module;
    }

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

        let account_address = signer::address_of(account);
        requires !contains(
            global<ValueHolderManifest>(@prover_examples).account_addresses,
            account_address
        );

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
}
