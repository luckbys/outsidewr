#!/usr/bin/env bash
set -euo pipefail
# Keep Godot's writable runtime files outside the checkout and restricted HOME.
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -d /workspace && -w /workspace ]]; then
  default_runtime_dir=/workspace/.godot-runtime
else
  default_runtime_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/morro-runtime"
fi
runtime_dir="${MORRO_RUNTIME_DIR:-${default_runtime_dir}}"
export XDG_DATA_HOME="${runtime_dir}/data"
export XDG_CONFIG_HOME="${runtime_dir}/config"
export XDG_CACHE_HOME="${runtime_dir}/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
exec "${GODOT_BIN:-godot}" --path "$project_dir" "$@"
