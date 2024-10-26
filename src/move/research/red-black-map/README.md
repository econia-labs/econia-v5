<!-- cspell:word movefmt -->

# Red-black map

## Layout

The `variants` directory contains several implementations based on
[Wikipedia's Red–black tree implementation guide][wikipedia guide]

| Variant | Description                                                  |
| ------- | ------------------------------------------------------------ |
| `a`     | Initial unfinished attempt, with ad hoc implementation stubs |
| `b`     | Designed to closely mimic the [Wikipedia guide]              |

## Move code interactions

From within any variant directory, for example `variants/a`:

1. Ensure `movefmt` is installed:

   ```sh
   aptos update movefmt
   ```

1. Test and format:

   ```sh
   aptos move test --dev --move-2
   aptos move fmt
   ```

[wikipedia guide]: https://en.wikipedia.org/wiki/Red%E2%80%93black_tree
