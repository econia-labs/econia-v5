# Contribution guidelines

See [RFC 2119](https://www.ietf.org/rfc/rfc2119.txt) for a guide to interpreting
the following key words in this document:

- MAY
- MUST
- MUST NOT
- OPTIONAL
- RECOMMENDED
- REQUIRED
- SHALL
- SHALL NOT
- SHOULD
- SHOULD NOT

## Continuous integration and development

### `pre-commit`

This repository uses [`pre-commit`](https://pre-commit.com/). If you add a new
filetype, you SHOULD add a new [hook](https://pre-commit.com/hooks.html).

From the repository root directory:

```sh
source src/sh/pre-commit.sh
```

See the `cfg/` directory for assorted formatter and linter configurations.

### GitHub actions

This repository uses [GitHub actions](https://docs.github.com/en/actions) to
perform assorted status checks. For example if you submit a pull request but do
not run [`pre-commit`](#pre-commit) then your pull request might get blocked.

## Pull requests

This repository handles pull requests (PRs) using the
[squash and merge method](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/about-merge-methods-on-github) <!-- markdownlint-disable-line MD013 -->

The Econia Labs team uses [Linear](https://linear.app/) for project management,
such that PRs titles start with tags of the form `[ECO-WXYZ]`. All PRs SHOULD
include a tag, so if you are submitting a PR as a community contributor, an
Econia Labs member may rename your PR with an auto-generated tag for internal
tracking purposes.

## Move style

1. [Reference](https://move-language.github.io/move/references.html) variable
   names MUST end in either `_ref` or `_ref_mut`, depending on mutability.
1. [Doc comments](https://move-language.github.io/move/coding-conventions.html?#comments) <!-- markdownlint-disable-line MD013 -->
   SHALL use Markdown syntax.
1. Incorrect comments are worse than no comments.
1. Variable names SHOULD be descriptive, with minor exceptions for things
   scenarios like math utility functions.
1. Error code names MUST start with `E_`, for example `E_NOT_ENOUGH_BASE`.
