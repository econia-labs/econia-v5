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

    invariant forall account_address: address where exists<ValueHolder>(
        account_address
    ):
        contains(
            global<ValueHolderManifest>(@prover_examples).account_addresses,
            account_address
        );

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
        ensures exists<ValueHolderManifest>(signer::address_of(prover_examples));
        ensures global<ValueHolderManifest>(signer::address_of(prover_examples))
            == ValueHolderManifest { account_addresses: vector[], value: DEFAULT_VALUE };
    }

    spec init_value_holder {
        requires exists<ValueHolderManifest>(@prover_examples); // Assumed per init_module.
        let account_address = signer::address_of(account);
        requires !contains(
            global<ValueHolderManifest>(@prover_examples).account_addresses,
            account_address
        );

        aborts_if exists<ValueHolder>(account_address);
        ensures exists<ValueHolder>(account_address);
        ensures global<ValueHolder>(signer::address_of(account)).value
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
