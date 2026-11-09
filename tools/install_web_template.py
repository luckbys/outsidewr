#!/usr/bin/env python3
"""Install only Godot's official single-threaded Web release template.

Read the ZIP directory and selected member over HTTPS byte ranges instead of
downloading the 1.25 GB archive for unrelated platforms. ZipFile validates the
outer member CRC and every file inside the downloaded template. TLS is verified
with Python's system trust store; no third-party Python dependencies are used.
"""

import io
from pathlib import Path
import urllib.request
import zipfile

VERSION = "4.6.3-stable"
URL = (
    "https://github.com/godotengine/godot-builds/releases/download/"
    f"{VERSION}/Godot_v{VERSION}_export_templates.tpz"
)
MEMBER = "templates/web_nothreads_release.zip"
DESTINATION = (
    Path(__file__).resolve().parents[1]
    / ".godot/web_templates/web_nothreads_release.zip"
)


class HttpsZipReader(io.RawIOBase):
    def __init__(self):
        super().__init__()
        with urllib.request.urlopen(
            urllib.request.Request(URL, method="HEAD"), timeout=30
        ) as response:
            self.length = int(response.headers["Content-Length"])
        self.position = 0

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.position

    def seek(self, offset, whence=io.SEEK_SET):
        if whence == io.SEEK_SET:
            self.position = offset
        elif whence == io.SEEK_CUR:
            self.position += offset
        elif whence == io.SEEK_END:
            self.position = self.length + offset
        else:
            raise ValueError("Invalid seek origin")
        if self.position < 0:
            raise ValueError("Negative seek")
        return self.position

    def read(self, size=-1):
        remaining = max(0, self.length - self.position)
        size = remaining if size < 0 else min(size, remaining)
        if not size:
            return b""
        if size > 32 * 1024 * 1024:
            raise ValueError("Unexpectedly large ZIP member")
        end = self.position + size - 1
        request = urllib.request.Request(
            URL, headers={"Range": f"bytes={self.position}-{end}"}
        )
        with urllib.request.urlopen(request, timeout=90) as response:
            expected = f"bytes {self.position}-{end}/{self.length}"
            if response.status != 206 or response.headers.get("Content-Range") != expected:
                raise RuntimeError("The official download server did not honor the byte range")
            data = response.read(size + 1)
        if len(data) != size:
            raise RuntimeError("Incomplete template download")
        self.position += size
        return data


def validate(path):
    with zipfile.ZipFile(path) as template:
        invalid = template.testzip()
        if invalid is not None:
            raise zipfile.BadZipFile(f"Template integrity error: {invalid}")
        names = template.namelist()
        if not any(name.endswith(".wasm") for name in names):
            raise zipfile.BadZipFile("The template has no WebAssembly runtime")


def main():
    if DESTINATION.exists():
        validate(DESTINATION)
        print(f"Web template already verified: Godot {VERSION}")
        return
    DESTINATION.parent.mkdir(parents=True, exist_ok=True)
    temporary = DESTINATION.with_suffix(".zip.tmp")
    try:
        with HttpsZipReader() as remote, zipfile.ZipFile(remote) as archive:
            # read() checks the archive member's uncompressed length and CRC.
            data = archive.read(MEMBER)
        temporary.write_bytes(data)
        validate(temporary)
        temporary.replace(DESTINATION)
        print(f"Official Web template verified and installed ({len(data):,} bytes)")
    finally:
        temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
