#!/usr/bin/env bash
# Parse-checks every GDScript file and runs the headless logic tests.
# Needs GODOT_BIN (set by tools/setup_godot.sh) and an already imported project.
set -uo pipefail

cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
mkdir -p build
fail=0

echo "== Checking GDScript syntax =="
count=0
while IFS= read -r script; do
  count=$((count + 1))
  out="$(timeout 120 "$GODOT_BIN" --headless --path . --check-only --script "res://${script}" 2>&1)"
  code=$?
  if [[ $code -ne 0 ]] || grep -qE 'SCRIPT ERROR|Parse Error|Compile Error' <<< "$out"; then
    echo "::error file=${script}::GDScript check failed"
    echo "$out"
    fail=1
  fi
done < <(find game tests -name '*.gd' 2> /dev/null | sort)
echo "Checked ${count} script(s)."

if [[ -f build/import.log ]] && grep -qE 'SCRIPT ERROR|Parse Error' build/import.log; then
  echo "::error::Script errors were reported while importing the project:"
  grep -E 'SCRIPT ERROR|Parse Error' build/import.log | head -n 40
  fail=1
fi

echo "== Running logic tests =="
if [[ -f tests/test_runner.gd ]]; then
  timeout 300 "$GODOT_BIN" --headless --path . --script res://tests/test_runner.gd 2>&1 | tee build/tests.log
  code=${PIPESTATUS[0]}
  if [[ $code -ne 0 ]]; then
    echo "::error::Logic tests failed (exit code ${code})"
    fail=1
  fi
else
  echo "No tests/test_runner.gd found, skipping."
fi

if [[ $fail -ne 0 ]]; then
  echo "FAILED: fix the problems above and run the workflow again."
  exit 1
fi
echo "All checks passed."