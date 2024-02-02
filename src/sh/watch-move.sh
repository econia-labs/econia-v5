#!/bin/sh
(
	local move_dir=src/move/econia
	(
		git ls-files $move_dir
		git ls-files $move_dir --exclude-standard --others
	) | entr -c -d aptos move test --coverage --dev --package-dir $move_dir
)
