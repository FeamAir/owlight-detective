#!/usr/bin/env bash
# Runs all checks headless: data validation (Python), GDScript unit tests, UI smoke run.
# Usage: game/tools/run_tests.sh            (from anywhere)
# Env:   GODOT — path to the Godot 4.7 binary (default: godot in PATH)
set -euo pipefail

GAME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT

echo "== data: YAML → JSON + checks"
python3 "$GAME_DIR/tools/data_build.py"
python3 "$GAME_DIR/tools/gen_placeholders.py"

echo "== import"
"$GODOT" --headless --path "$GAME_DIR" --import >"$LOG_DIR/import.log" 2>&1 || { cat "$LOG_DIR/import.log"; exit 1; }

fail=0
run() {   # name, script
  local name="$1" script="$2"
  echo "== $name"
  # watchdog: a script error inside an awaited UI step would otherwise hang the run
  if ! timeout 900 "$GODOT" --headless --path "$GAME_DIR" -s "$script" >"$LOG_DIR/$name.log" 2>&1; then
    fail=1
  fi
  # script errors do not change the exit code of the engine — treat them as failures
  if grep -qE "SCRIPT ERROR|Parse Error" "$LOG_DIR/$name.log"; then
    fail=1
  fi
  grep -E "FAIL|SCRIPT ERROR|Parse Error|tests,|SMOKE" "$LOG_DIR/$name.log" || true
}
run unit res://tests/run_tests.gd
run smoke res://tests/smoke_ui.gd

if [ "$fail" -ne 0 ]; then
  echo "TESTS FAILED"
  exit 1
fi
echo "ALL TESTS PASSED"
