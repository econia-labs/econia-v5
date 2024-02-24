#!/bin/sh
(
	clear
	local module=$1
	local move_dir=src/move/econia
	aptos move coverage source --dev --module $module --package-dir $move_dir
)
