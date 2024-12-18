module prover_examples::value_holder {
    use std::signer;

    const DEFAULT_VALUE: u8 = 0;

    struct ValueHolder has key {
        value: u8
    }

    struct ValueHolderManifest has key {
        account_addresses: vector<address>,
        value: u8
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
}
