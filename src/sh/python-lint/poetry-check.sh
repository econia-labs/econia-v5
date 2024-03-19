#!/bin/sh

POETRY_SUBDIRECTORY=./src/python/hooks

poetry --version >/dev/null 2>&1 || {
	echo "Poetry is not installed. Please install poetry to continue."
	exit 1
}

cd $POETRY_SUBDIRECTORY || exit 1

poetry check --quiet || {
	echo "Poetry check failed."
	exit 1
}

exit 0
