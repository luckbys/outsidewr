#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
preset="${1:-Web}"
case "$preset" in
  Web)
    output_dir=builds/web
    archive_path=builds/morro-em-disputa-web.zip
    ;;
  Web3D)
    output_dir=builds/web-3d
    archive_path=builds/morro-em-disputa-3d-web.zip
    ;;
  *) echo "Preset desconhecido: $preset. Use Web ou Web3D." >&2; exit 1 ;;
esac
python3 tools/install_web_template.py
mkdir -p "$output_dir"
touch builds/.gdignore
bash tools/godot.sh --headless --editor --import --quit
bash tools/godot.sh --headless --export-release "$preset" "$output_dir/index.html"
# Preserve relative paths when hosted below a repository path, e.g. GitHub Pages.
touch "$output_dir/.nojekyll"
python3 - "$output_dir" "$archive_path" <<'PY'
from pathlib import Path
import sys
import zipfile
directory = Path(sys.argv[1])
archive_path = Path(sys.argv[2])
with zipfile.ZipFile(archive_path, 'w', zipfile.ZIP_DEFLATED) as package:
    for path in sorted(directory.iterdir()):
        if path.is_file():
            package.write(path, path.name)
print('Web build:', directory / 'index.html')
print('Upload package:', archive_path)
PY
