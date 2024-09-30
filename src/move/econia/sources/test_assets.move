// cspell:words auids
#[test_only]
module econia::test_assets {

    use aptos_framework::account;
    use aptos_framework::fungible_asset::{Self, BurnRef, MintRef, Metadata, TransferRef};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::object::{Self, Object, ObjectGroup};
    use std::features;
    use std::option;
    use std::string;

    const BASE_SYMBOL: vector<u8> = b"BASE";
    const BASE_DECIMALS: u8 = 8;
    const QUOTE_SYMBOL: vector<u8> = b"QUOTE";
    const QUOTE_DECIMALS: u8 = 6;

    struct TestAssetsMetadata has key {
        base_metadata: Object<Metadata>,
        quote_metadata: Object<Metadata>
    }

    #[resource_group_member(group = ObjectGroup)]
    struct AssetRefs has key {
        burn_ref: BurnRef,
        mint_ref: MintRef,
        transfer_ref: TransferRef
    }

    public fun get_metadata(): (Object<Metadata>, Object<Metadata>) acquires TestAssetsMetadata {
        ensure_assets_initialized();
        let test_assets_metadata_ref = borrow_global<TestAssetsMetadata>(@econia);
        (test_assets_metadata_ref.base_metadata, test_assets_metadata_ref.quote_metadata)
    }

    public fun ensure_assets_initialized() {
        if (exists<TestAssetsMetadata>(@econia)) return;
        let framework = account::create_signer_for_test(@std);
        features::change_feature_flags(
            &framework, vector[features::get_auids()], vector[]
        );
        move_to(
            &account::create_signer_for_test(@econia),
            TestAssetsMetadata {
                base_metadata: init_test_asset(BASE_SYMBOL, BASE_DECIMALS),
                quote_metadata: init_test_asset(QUOTE_SYMBOL, QUOTE_DECIMALS)
            }
        )
    }

    public fun burn(
        owner: address, base_amount: u64, quote_amount: u64
    ) acquires AssetRefs, TestAssetsMetadata {
        ensure_assets_initialized();
        let test_assets_metadata_ref = borrow_global<TestAssetsMetadata>(@econia);
        burn_from_metadata(owner, test_assets_metadata_ref.base_metadata, base_amount);
        burn_from_metadata(owner, test_assets_metadata_ref.quote_metadata, quote_amount);
    }

    public fun mint(
        owner: address, base_amount: u64, quote_amount: u64
    ) acquires AssetRefs, TestAssetsMetadata {
        let test_assets_metadata_ref = borrow_global<TestAssetsMetadata>(@econia);
        mint_from_metadata(owner, test_assets_metadata_ref.base_metadata, base_amount);
        mint_from_metadata(owner, test_assets_metadata_ref.quote_metadata, quote_amount);
    }

    public fun burn_from_metadata(
        owner: address,
        metadata: Object<Metadata>,
        amount: u64
    ) acquires AssetRefs {
        ensure_assets_initialized();
        let asset_refs_ref = borrow_global<AssetRefs>(object::object_address(&metadata));
        primary_fungible_store::burn(&asset_refs_ref.burn_ref, owner, amount);
    }

    public fun mint_from_metadata(
        owner: address,
        metadata: Object<Metadata>,
        amount: u64
    ) acquires AssetRefs {
        ensure_assets_initialized();
        let asset_refs_ref = borrow_global<AssetRefs>(object::object_address(&metadata));
        primary_fungible_store::mint(&asset_refs_ref.mint_ref, owner, amount);
    }

    fun init_test_asset(symbol: vector<u8>, decimals: u8): Object<Metadata> {
        let constructor_ref = object::create_sticky_object(@econia);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &constructor_ref,
            option::none(),
            string::utf8(b""),
            string::utf8(symbol),
            decimals,
            string::utf8(b""),
            string::utf8(b"")
        );
        move_to(
            &object::generate_signer(&constructor_ref),
            AssetRefs {
                burn_ref: fungible_asset::generate_burn_ref(&constructor_ref),
                mint_ref: fungible_asset::generate_mint_ref(&constructor_ref),
                transfer_ref: fungible_asset::generate_transfer_ref(&constructor_ref)
            }
        );
        object::object_from_constructor_ref(&constructor_ref)
    }
}
