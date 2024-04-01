# Overview

The python scripts in this folder are intended to be run in a python-based
`pre-commit` harness that facilitates running custom python scripts in
`pre-commit`, both for developers locally and in CI with github actions.

If you are contributing to the python files in this repository for the first
time, make sure to [install the required tools first].

If you want to quickly format your python files so that they pass the
`pre-commit` checks, you can [run our formatting script].

## Running `pre-commit` hooks locally

To avoid your PR contributions failing the CI pipeline checks, you can install
the `pre-commit` hooks locally so that they automatically run right before you
add a new commit.

### Installing the required tools

To properly install the full `pre-commit` environment for this repository,
you'll need the following command-line tools:

- `git`, `python`, and `pip` (if you're not using `brew`)
- `poetry` and `pre-commit`

You can install all of these tools with your preferred package manager.
If you have `python` and `pip` installed already, you might use:

- `pip install poetry`
- `pip install pre-commit`

If you use `brew` on MacOS:

- `brew install poetry`
- `brew install pre-commit`

### Installing the `poetry` and `pre-commit` environments

You'll also need to set up your `poetry` and `pre-commit` environments for this
repository:

First ensure you're in the `econia-v5` repository at the root directory. If you
haven't cloned it yet, this might look something like:

```shell
git clone https://github.com/econia-labs/econia-v5 && cd econia-v5
```

Then install the python hooks `poetry` dependencies:

```shell
poetry install -C src/python/hooks --no-root
```

To install `pre-commit` to run prior to every time you `git commit ...` when
relevant files change:

```shell
pre-commit install --config cfg/pre-commit-config.yaml
```

Or you can run the hooks manually yourself against all files:

```shell
pre-commit run --all-files --config cfg/pre-commit-config.yaml
```

If you'd like to bypass `pre-commit` hooks for any reason once you've installed
our `pre-commit` hooks with `pre-commit-config.yaml`, you can bypass the checks
with:

```shell
git commit -m "Some change pre-commit hooks..." --no-verify
```

Note that this will allow you to push your commit onto your branch even if it
fails the `pre-commit` checks, but will likely fail in CI when it runs its
own `pre-commit` checks.

## Running the python formatters

Since our `pre-commit` hooks generally avoid making changes in place during
the `pre-commit` hook suite, you may need to make changes to your python files
to pass the checks.

Some of these changes may require you to make manual changes, but if they
are issues with formatting and linting, you can easily fix a large portion
of them by running our formatting script:

```shell
./src/sh/python-lint/format.sh
```

[install the required tools first]: #running-pre-commit-hooks-locally
[run our formatting script]: #running-the-python-formatters
