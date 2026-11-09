#!/usr/bin/env python3
"""Check the actual exported game served by the container; stdlib only."""

import argparse
import gzip
import urllib.error
import urllib.request


def check_site(base_url):
    base_url = base_url.rstrip("/")

    def fetch(path, method="GET", headers=None):
        request = urllib.request.Request(
            base_url + path, method=method, headers=headers or {}
        )
        return urllib.request.urlopen(request, timeout=15)

    with fetch("/") as response:
        assert response.status == 200
        assert response.headers.get_content_type() == "text/html"
        assert b"GODOT_CONFIG" in response.read(), "Game HTML was not served"
        assert "no-cache" in response.headers.get("Cache-Control", "")
    print("PASS: Game HTML loads and revalidates cached files")

    with fetch("/index.wasm", method="HEAD") as response:
        assert response.status == 200
        assert response.headers.get_content_type() == "application/wasm"
        assert int(response.headers["Content-Length"]) > 1_000_000
    print("PASS: WebAssembly runtime has the correct MIME type and size")

    with fetch("/index.pck") as response:
        assert response.read(4) == b"GDPC", "Game pack was replaced by an HTML page"
    print("PASS: Actual Godot game pack is served")

    with fetch("/index.js", headers={"Accept-Encoding": "gzip"}) as response:
        assert response.headers.get_content_type() in (
            "application/javascript", "text/javascript"
        )
        assert response.headers.get("Content-Encoding") == "gzip"
        assert len(gzip.decompress(response.read())) > 1000
    print("PASS: JavaScript runtime is served with valid gzip compression")

    try:
        with fetch("/missing-game-file.wasm"):
            raise AssertionError("Missing files must return 404")
    except urllib.error.HTTPError as error:
        assert error.code == 404
    print("PASS: Missing game files return 404")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base_url", help="HTTP(S) address of the running container")
    arguments = parser.parse_args()
    check_site(arguments.base_url)
