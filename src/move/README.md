<!-- cspell:word entr -->

# Move source code

## Useful commands

1. Run coverage testing and format source code on file change:

   ```sh
   git ls-files | entr -c sh -c " \
       aptos move test --dev --move-2 --coverage &&
       aptos move fmt
   "
   ```

1. Display coverage against bytecode on file change:

   ```sh
   git ls-files | entr -c aptos move coverage bytecode --dev --move-2 \
       --module <MODULE>
   ```

1. After [installing the Move Prover], to prove a package:

   ```sh
   aptos move prove --dev --move-2 --trace
   ```

[installing the move prover]: https://aptos.dev/en/build/cli/setup-cli/install-move-prover
