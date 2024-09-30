Ensure proper `movefmt` version >= `1.0.5`:

```sh
aptos update movefmt --target-version 1.0.5
```

Test and format:

```sh
aptos move test --dev --move-2
aptos move fmt
```