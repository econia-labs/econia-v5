#!/bin/sh
# cspell:words pyproject

if [ "$GITHUB_ACTIONS" = "true" ]; then
	echo 'GitHub Actions environment detected, skipping `poetry check`...'
	exit 0
fi

poetry --version >/dev/null 2>&1 || {
	echo "Poetry is not installed. Please install poetry to continue."
	exit 1
}

POETRY_SUBDIRECTORY=./src/python/hooks
cd $POETRY_SUBDIRECTORY || exit 1

# Attempt to install the poetry dependencies.
poetry install --no-root || {
	echo "Poetry install failed."
	exit 1
}

# Check if `poetry.lock` is consistent with `pyproject.toml`.
# We run both commands in case their version of poetry doesn't
# support `poetry check --lock`.
poetry check --lock || poetry lock --check --no-update || {
	echo 'Poetry lock file is out of date. Running `poetry lock --no-update`...'
	poetry lock --no-update || {
		echo "Poetry lock failed."
		exit 1
	}
	echo "Exiting successfully..?"
	exit 0
}

exit 0
