# Contribution guidelines

## Continuous integration and development

### `pre-commit`

This repository uses [`pre-commit`](https://pre-commit.com/). If you add a new
filetype, consider adding a new [hook](https://pre-commit.com/hooks.html).

From the repository root directory:

```sh
source src/sh/pre-commit.sh
```

See the `cfg/` directory for assorted formatter and linter configurations.

### GitHub actions

This repository uses [GitHub actions](https://docs.github.com/en/actions) to
perform assorted status checks. For example if you submit a pull request but do
not run [`pre-commit`](#pre-commit) then your pull request might get blocked.
