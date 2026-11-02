#!/usr/bin/env bash
# Checks every GDScript file for errors, starts the project headless for a moment, and
# runs the headless logic tests. Needs GODOT_BIN (set by tools/setup_godot.sh) and an
# already imported project.
set -uo pipefail

cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
mkdir -p build
fail=0

# When a script is checked on its own, Godot does not know the autoload names, and a script
# that depends on a failing script reports a knock-on error. These lines are not real
# problems and are ignored. Everything else counts.
BENIGN='Identifier not found: (Config|Settings|Audio|Session|Net)\b|Failed to compile depended scripts|Could not preload resource script|Could not resolve script|Could not parse script from'

# Reads Godot output on stdin and prints only the real parse/compile errors.
real_errors() {
  grep -E 'SCRIPT ERROR: (Parse|Compile) Error:' | grep -Ev "$BENIGN" || true
}

echo "== Checking GDScript syntax =="
count=0
while IFS= read -r script; do
  count=$((count + 1))
  out="$(timeout 120 "$GODOT_BIN" --headless --path . --check-only --script "res://${script}" 2>&1)"
  bad="$(real_errors <<< "$out")"
  if [[ -n "$bad" ]]; then
    echo "::error file=${script}::GDScript check failed"
    echo "$bad"
    fail=1
  fi
done < <(find game tests -name '*.gd' 2> /dev/null | sort)
echo "Checked ${count} script(s)."

echo "== Checking the import log =="
if [[ -f build/import.log ]]; then
  bad_import="$( { real_errors < build/import.log; grep -E '^ERROR: res://.*Parse Error' build/import.log || true; } )"
  if [[ -n "$bad_import" ]]; then
    echo "::error::Errors were reported while importing the project:"
    echo "$bad_import" | head -n 40
    fail=1
  fi
fi

echo "== Starting the project headless =="
timeout 180 "$GODOT_BIN" --headless --path . --quit-after 120 > build/boot.log 2>&1
boot_code=$?
if [[ $boot_code -eq 124 ]]; then
  echo "::warning::The project did not exit within 180 seconds"
fi
bad_boot="$(real_errors < build/boot.log)"
if [[ -n "$bad_boot" ]]; then
  echo "::error::Script errors while starting the project:"
  echo "$bad_boot" | head -n 40
  fail=1
fi
# Runtime errors can be caused by the headless (display-less) mode, so they are shown as
# warnings instead of failing the build. Read them: they often point at real bugs.
runtime="$(grep -E 'SCRIPT ERROR:' build/boot.log | grep -Ev 'Parse Error|Compile Error' | head -n 20 || true)"
if [[ -n "$runtime" ]]; then
  echo "::warning::Runtime script errors while starting the project (see log)"
  echo "$runtime"
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