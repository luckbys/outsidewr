#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
python3 tools/install_web_template.py
mkdir -p builds/web
touch builds/.gdignore
bash tools/godot.sh --headless --editor --import --quit
bash tools/godot.sh --headless --export-release Web builds/web/index.html
# Preserve relative paths when hosted below a repository path, e.g. GitHub Pages.
touch builds/web/.nojekyll
python3 - <<'PY'
from pathlib import Path
import zipfile
directory = Path('builds/web')
with zipfile.ZipFile('builds/morro-em-disputa-web.zip', 'w', zipfile.ZIP_DEFLATED) as package:
    for path in sorted(directory.iterdir()):
        if path.is_file():
            package.write(path, path.name)
print('Web build: builds/web/index.html')
print('Upload package: builds/morro-em-disputa-web.zip')
PY
