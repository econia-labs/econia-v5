#!/bin/bash
# cspell:words realpath, autoflake, venv

# Capture the first argument, which is the command we're wrapping for
# the pre-commit hook.
COMMAND=$1
# Then skip it so we can pass "$@" to the command.
shift

# Capture and skip like above.
ERROR_MESSAGE=$1
shift

# This is the path passed in to the script from the pre-commit hook,
# it tells poetry where to look for the files.
POETRY_SUBDIRECTORY="./src/python/hooks"

RELATIVE_PATHS=""

# Convert all paths to relative paths.
for path in "$@"; do
	RELATIVE=$(realpath --relative-to="$POETRY_SUBDIRECTORY" "$path")
	RELATIVE_PATHS="$RELATIVE_PATHS $RELATIVE"
done

cd $POETRY_SUBDIRECTORY || exit 1

# Then run the script passed into this script, with the relative paths.
# This is so we can define individual pre-commit hooks for each linter,
# each with their own output status codes.
fail=false

eval $COMMAND $RELATIVE_PATHS || fail=true

if [ "$fail" = true ]; then
	echo ''
	echo $ERROR_MESSAGE
	exit 1
fi

exit 0
