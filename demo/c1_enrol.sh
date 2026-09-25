#!/usr/bin/env bash
# Issue a provisioning blob for a new device, and print the exact steps to
# paste it onto the board's console.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

OUT=$("$DEPUTY" device enrol)
DEVICE_ID=$(echo "$OUT" | grep -o '"device_id": *"[^"]*"' | head -1 | cut -d'"' -f4)
BLOB=$(echo "$OUT" | grep -o '"blob": *"[^"]*"' | head -1 | cut -d'"' -f4)
EXPIRES=$(echo "$OUT" | grep -o '"expires_at": *"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$DEVICE_ID" ] || [ -z "$BLOB" ]; then
    echo "Could not parse the enrol output:" >&2
    echo "$OUT" >&2
    exit 1
fi

echo "$DEVICE_ID" > "$DEVICE_ID_FILE"

PROBE_PORT=$(find_port 2e8a) || PROBE_PORT="<Debug Probe not found>"

cat <<EOF

Device ID: $DEVICE_ID
Saved to: $DEVICE_ID_FILE
Blob expires: $EXPIRES

In a real terminal window, not this one:

1. Run:
   probe-rs reset --chip RP2350 && picocom -b 115200 $PROBE_PORT

2. Wait for this line:
   no device identity. paste a provisioning blob ...

3. Paste this line within 30 seconds, then press Enter:

$BLOB

4. Confirm this line appears:
   stored 276 B at sheriff/provision

5. Exit picocom: press Ctrl-a, then press Ctrl-x.
EOF
