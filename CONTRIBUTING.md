<!--- cspell:words wxyz -->

# Contribution Guidelines

The key words `MUST`, `MUST NOT`, `REQUIRED`, `SHALL`, `SHALL NOT`, `SHOULD`,
`SHOULD NOT`, `RECOMMENDED`,  `MAY`, and `OPTIONAL` in this document are to be
interpreted as described in [RFC 2119].

These keywords `SHALL` be in `monospace` for ease of identification.

## Continuous integration and development

### `pre-commit`

This repository uses [`pre-commit`]. If you add a new filetype, you `SHOULD` add
a new [hook][pre-commit hook].

From the repository root directory:

```sh
source src/sh/pre-commit.sh
```

See the `cfg/` directory for assorted formatter and linter configurations.

### GitHub actions

This repository uses [GitHub actions] to perform assorted status checks. If you
submit a pull request but do not [run `pre-commit`] then your pull request might
get blocked.

## Pull requests

This repository handles pull requests (PRs) using the [squash and merge method].

The Econia Labs team uses [Linear] for project management, such that PRs titles
start with tags of the form `[ECO-WXYZ]`. All PRs `MUST` include a tag, so if
you are submitting a PR as a community contributor, an Econia Labs member
`SHALL` change your PR title to include an auto-generated tag for internal
tracking purposes.

Pull requests `MUST` include a description written using imperative form that
"tells the repository what to do".

Pull request titles `MUST` also use imperative form, with the first letter after
the tag capitalized. For example `[ECO-WXYZ] Update something in the repo`.

Commit titles `SHOULD` use a similar format, but without a leading tag.

## Style

### General

1. Incorrect comments are worse than no comments.
1. Minimize maintainability dependencies.
1. Prefer compact code blocks, delimited by section comments rather than
   whitespace.
1. Titles `SHALL` use `Title Case` while headers `SHALL` use `Sentence case`.

### Markdown

1. [Reference links] are `REQUIRED` where possible, for readability and for ease
   of linting.

### Move

1. [Reference][move references] variable names `MUST` end in either `_ref` or
   `_ref_mut`, depending on mutability.
1. [Doc comments] `MUST` use Markdown syntax.
1. Variable names `SHOULD` be descriptive, with minor exceptions for scenarios
   like math utility functions.
1. Error code names `MUST` start with `E_`, for example `E_NOT_ENOUGH_BASE`.
1. Econia `SHALL` be implemented according to the [architecture specification].

[architecture specification]: doc/architecture-specification.md
[doc comments]: https://move-language.github.io/move/coding-conventions.html?#comments
[github actions]: https://docs.github.com/en/actions
[linear]: https://pre-commit.com/hooks.html
[move references]: https://move-language.github.io/move/references.html
[pre-commit hook]: https://pre-commit.com/hooks.html
[reference links]: https://mdformat.readthedocs.io/en/stable/users/style.html#reference-links
[rfc 2119]: https://www.ietf.org/rfc/rfc2119.txt
[run `pre-commit`]: #pre-commit
[squash and merge method]: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/about-merge-methods-on-github
[`pre-commit`]: https://github.com/pre-commit/pre-commit
