#!/usr/bin/env bash
# Open the serial console on the Debug Probe's UART bridge (vendor 2e8a).

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

PORT=$(find_port 2e8a) || {
    echo "Debug Probe not found. Check the USB cable." >&2
    exit 1
}

echo "Console on $PORT. Exit with Ctrl-a then Ctrl-x." >&2
picocom -b 115200 "$PORT"
