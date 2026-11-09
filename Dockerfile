# syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM python:3.13-slim-bookworm AS build

ARG BUILDARCH

# Optional proxy_ca secret supports managed networks without disabling TLS.
RUN --mount=type=secret,id=proxy_ca <<'SH'
set -eu
if [ -f /run/secrets/proxy_ca ]; then
    export SSL_CERT_FILE=/run/secrets/proxy_ca
fi
apt-get -o "Acquire::https::CaInfo=${SSL_CERT_FILE:-/etc/ssl/certs/ca-certificates.crt}" update
apt-get -o "Acquire::https::CaInfo=${SSL_CERT_FILE:-/etc/ssl/certs/ca-certificates.crt}" install -y --no-install-recommends libfontconfig1 fonts-dejavu-core
rm -rf /var/lib/apt/lists/*
python3 - <<'PY'
import hashlib
import io
import os
from pathlib import Path
import urllib.request
import zipfile

archives = {
    "amd64": (
        "x86_64",
        "a035258da32b77f966a5376f9fa29c30a6adde826a85ba918e1605bd1fc9823eba7d85f1dd5e748956bd2ba72827c0025ffa11bb82aec91128c407a2e723c99c",
    ),
    "arm64": (
        "arm64",
        "447381de9ccc68aa02f37e279322289f7ddf88ce9b839ed88a97c73e01cdcda46e026897e5d88722e08491f71b3d74f72dfeb22ec7e3add6fd3e9bfbbdad6751",
    ),
}
architecture, checksum = archives[os.environ["BUILDARCH"]]
name = f"Godot_v4.6.3-stable_linux.{architecture}"
url = f"https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/{name}.zip"
with urllib.request.urlopen(url, timeout=120) as response:
    data = response.read()
if hashlib.sha512(data).hexdigest() != checksum:
    raise SystemExit("Godot archive SHA-512 verification failed")
with zipfile.ZipFile(io.BytesIO(data)) as archive:
    Path("/usr/local/bin/godot").write_bytes(archive.read(name))
Path("/usr/local/bin/godot").chmod(0o755)
PY
groupadd --gid 1000 builder
useradd --uid 1000 --gid 1000 --create-home builder
mkdir /app
chown builder:builder /app
SH

WORKDIR /app
COPY --chown=builder:builder project.godot export_presets.cfg ./
COPY --chown=builder:builder assets/ assets/
COPY --chown=builder:builder resources/ resources/
COPY --chown=builder:builder scenes/ scenes/
COPY --chown=builder:builder scripts/ scripts/
COPY --chown=builder:builder tests/ tests/
COPY --chown=builder:builder tools/ tools/

USER builder
ENV MORRO_RUNTIME_DIR=/tmp/morro-runtime
RUN bash tools/setup.sh
RUN --mount=type=secret,id=proxy_ca,uid=1000,gid=1000 <<'SH'
set -eu
if [ -f /run/secrets/proxy_ca ]; then
    export SSL_CERT_FILE=/run/secrets/proxy_ca
fi
bash tools/export_web.sh
SH

FROM nginx:1.28-alpine AS runtime
COPY --chmod=644 docker/nginx.conf /etc/nginx/nginx.conf
COPY --from=build --chown=nginx:nginx /app/builds/web/ /usr/share/nginx/html/
USER nginx
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -Y off -q -O /dev/null http://127.0.0.1:8080/index.html || exit 1
ENTRYPOINT ["nginx"]
CMD ["-g", "daemon off;"]
