#!/usr/bin/env bash
# Inlines local <img src="./*.svg"> references in deck.html as base64 data URIs
# so the rendered deck is a single standalone file with no external assets.
set -euo pipefail

cd "$(dirname "$0")"

python3 - "$@" <<'PY'
import base64
import re
import sys

html_path = sys.argv[1] if len(sys.argv) > 1 else "deck.html"

with open(html_path, "r", encoding="utf-8") as f:
    html = f.read()

def embed(match):
    src = match.group(1)
    if not src.startswith("./") or not src.endswith(".svg"):
        return match.group(0)
    path = src[2:]
    with open(path, "rb") as img:
        data = base64.b64encode(img.read()).decode("ascii")
    data_uri = f"data:image/svg+xml;base64,{data}"
    return match.group(0).replace(src, data_uri)

html = re.sub(r'src="(\./[^"]+\.svg)"', embed, html)

with open(html_path, "w", encoding="utf-8") as f:
    f.write(html)

print(f"Embedded local SVGs into {html_path}")
PY
