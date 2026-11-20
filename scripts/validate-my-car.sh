#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
godot="${GODOT_BIN:-godot}"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/config" "$work/data"

run_check() {
  local step="$1"
  shift
  local log="$work/$step.log"
  if ! timeout 120s "$@" > "$log" 2>&1; then
    cat "$log"
    return 1
  fi
  cat "$log"
  if rg -q '^((SCRIPT )?ERROR:|WARNING:.*leak|FAIL )' "$log"; then
    return 1
  fi
}

export XDG_CONFIG_HOME="$work/config" XDG_DATA_HOME="$work/data"
run_check import "$godot" --headless --path "$repo/Masalik-3D" --editor --import
run_check startup "$godot" --headless --path "$repo/Masalik-3D" --quit-after 15
run_check gameplay "$godot" --headless --path "$repo/Masalik-3D" --fixed-fps 60 --script res://tests/headless_test_runner.gd
