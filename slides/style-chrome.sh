#!/usr/bin/env bash
# Injects CSS for the bespoke player chrome (progress bar, controls) that lives
# outside the per-slide <section> elements. Marp scopes theme CSS to `section`,
# so these rules can't be set via the theme stylesheet and are appended
# directly to deck.html's <head> instead.
set -euo pipefail

cd "$(dirname "$0")"

python3 - "$@" <<'PY'
import re
import sys

html_path = sys.argv[1] if len(sys.argv) > 1 else "deck.html"

with open(html_path, "r", encoding="utf-8") as f:
    html = f.read()

chrome_css = """<style>
.bespoke-progress-parent {
  position: fixed;
  inset: auto 0 0 0;
  height: 10px;
}
.bespoke-progress-parent + :where(.bespoke-marp-parent) {
  top: 0;
}
.bespoke-progress-bar {
  background: #9c2d1e !important;
}
</style>
"""

if "</head>" not in html:
    raise SystemExit(f"Could not find </head> in {html_path}")

html = html.replace("</head>", chrome_css + "</head>", 1)

with open(html_path, "w", encoding="utf-8") as f:
    f.write(html)

print(f"Injected chrome CSS into {html_path}")
PY
