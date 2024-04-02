# Overview

The Python scripts in this folder are intended to be run in a Python-based
`pre-commit` harness that facilitates running custom Python scripts in
`pre-commit`, both for developers locally and in CI with github actions.

If you haven't yet, make sure to [install the required tools first].

If you want to quickly format your Python files so that they pass the
`pre-commit` checks, you can [run our formatting script].

## Running the python formatters

Since our `pre-commit` hooks generally avoid making changes in place during
the `pre-commit` hook suite, you may need to make changes to your Python files
to pass the checks.

Some of these changes may require you to make manual changes, but if they
are issues with formatting and linting, you can easily fix a large portion
of them by running our formatting script:

```shell
./src/sh/python-lint/format.sh
```

While you can directly run the Python formatter script, for ease of use, we've
provided a `.src/sh/python-lint/format.sh` script to verify your Poetry
dependencies and run anywhere, regardless of your current working directory.

[install the required tools first]: ../../../cfg/README.md
[run our formatting script]: #running-the-python-formatters
