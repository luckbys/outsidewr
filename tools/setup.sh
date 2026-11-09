#!/usr/bin/env bash
set -euo pipefail
tools_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
godot_version="$(bash "$tools_dir/godot.sh" --version)"
case "$godot_version" in
  4.6.*) ;;
  *) echo "Use Godot 4.6.x (testado em 4.6.3). Encontrado: $godot_version" >&2; exit 1 ;;
esac
bash "$tools_dir/godot.sh" --headless --editor --import --quit
bash "$tools_dir/godot.sh" --headless --script tests/match_smoke.gd
bash "$tools_dir/godot.sh" --headless --script tests/input_smoke.gd
