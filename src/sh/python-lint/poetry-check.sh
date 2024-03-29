#!/bin/sh

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

# Run `poetry check` first, `poetry lock --check` in case their version of poetry
# doesn't support `poetry check`.
poetry check --lock --quiet || poetry lock --check --no-update --quiet || {
	echo "Poetry lock file is out of date. Running poetry install."
	poetry install --no-root || {
		echo "Poetry install failed."
		exit 1
	}
	exit 0
}

exit 0
