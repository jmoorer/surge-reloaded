#!/bin/sh
# Runs every tests/test_*.gd headless at a fixed 60 fps; fails if any test fails or hangs.
# Usage: tools/run_tests.sh [pattern]
cd "$(dirname "$0")/.." || exit 1
status=0
for t in tests/test_${1:-*}.gd; do
	echo "== $t"
	out=$(perl -e 'alarm 240; exec @ARGV' godot --headless --fixed-fps 60 --path . --script "res://$t" 2>&1)
	code=$?
	echo "$out" | grep -E "^(PASS|FAIL)|failure\(s\)|SCRIPT ERROR|^ERROR"
	[ $code -ne 0 ] && { echo "!! exit $code"; status=1; }
done
exit $status
