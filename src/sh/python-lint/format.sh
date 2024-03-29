#!/bin/sh
# cspell:words toplevel
ROOT_DIR=$(git rev-parse --show-toplevel)
$ROOT_DIR/src/sh/python-lint/./run-in-poetry-subdir.sh "poetry run python -m format"
