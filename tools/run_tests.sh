#!/usr/bin/env bash
# Runs the smoke check and every gameplay test (tests/test_*.gd).
# A test fails if it exits with a non-zero code OR prints a script error: GDScript keeps running
# after a runtime error, so the exit code alone can hide a silently skipped check.
#
#   ./tools/run_tests.sh                 (needs `godot` in the PATH)
#   ./tools/run_tests.sh test_skills test_player   (only these tests)
#   GODOT=/path/to/godot ./tools/run_tests.sh
#
# On Windows use Git Bash and point GODOT to the *_console.exe build, e.g.
#   GODOT="$HOME/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" ./tools/run_tests.sh

set -u
GODOT="${GODOT:-godot}"
# A test that never reaches quit() (e.g. an error aborted it) must not hang the whole run.
TEST_TIMEOUT="${TEST_TIMEOUT:-180}"
status=0

cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

run() {
	local label="$1"
	shift
	local output code
	output=$(timeout "$TEST_TIMEOUT" "$GODOT" --headless --path . "$@" 2>&1)
	code=$?
	if [ $code -ne 0 ] || echo "$output" | grep -qE "SCRIPT ERROR|Parse Error"; then
		echo "FAIL $label (exit code $code$([ $code -eq 124 ] && echo ', timed out'))"
		echo "$output" | grep -E "^FAIL|SCRIPT ERROR|Parse Error|TIMEOUT|Executed" | head -20
		status=1
	else
		echo "ok   $label ($(echo "$output" | grep -c '^PASS') checks)"
	fi
}

if [ $# -eq 0 ]; then
	run "smoke check" --script res://tests/run_checks.gd
	set -- $(for test in tests/test_*.gd; do basename "$test" .gd; done)
fi
for name in "$@"; do
	run "$name" --script "res://tests/$name.gd"
done

if [ $status -eq 0 ]; then
	echo "All tests passed."
else
	echo "Some tests FAILED."
fi
exit $status
