#!/bin/bash
# cspell:words realpath, autoflake, isort, mypy, toplevel

ROOT_DIR=$(git rev-parse --show-toplevel)
PYTHON_DIR=$ROOT_DIR/src/python
POETRY_SUBDIRECTORY=$PYTHON_DIR/hooks

poetry --version >/dev/null 2>&1 || {
	echo "Poetry is not installed. Please install poetry to continue."
	exit 1
}

cd $POETRY_SUBDIRECTORY || exit 1

before_files=$(git ls-files -mo --exclude-standard)

echo -e "Running poetry install....................................."
poetry install -C $POETRY_SUBDIRECTORY --no-interaction --no-root

# Note that `python_files` should match pre-commit's pattern for python files
# as long as all python files in the repository are confined to `src/python`.
file_list=$(git -C "$PYTHON_DIR" ls-files | grep '\.py$')
# Set the IFS to a newline so that we can read the file list into an array.
IFS=$'\n'
# Read the file list into an array, converting each file to an absolute path
# by prepending the python directory to each file path.
read -r -d '' -a python_files <<<"$(echo "$file_list" | sed "s|^|$PYTHON_DIR/|")"
# Unset IFS for good measure.
unset IFS

if [ ${#python_files[@]} -eq 0 ]; then
	echo "No Python files found in $PYTHON_DIR. Exiting..."
	exit 0
fi

echo -e "\nRunning autoflake.........................................."
poetry run autoflake -i --remove-all-unused-imports --remove-unused-variables --ignore-init-module-imports "${python_files[@]}"

echo -e "\nRunning black.............................................."
poetry run black "${python_files[@]}"

echo -e "\nRunning isort.............................................."
poetry run isort "${python_files[@]}"

echo -e "\nRunning flake8............................................."
poetry run flake8 "${python_files[@]}"

echo -e "\nRunning mypy..............................................."
poetry run mypy "${python_files[@]}"

echo -e "\nRunning python -m file-name-conventions...................."
poetry run python -m file-name-conventions "${python_files[@]}"
echo ''

cd ../../..

exit 0
