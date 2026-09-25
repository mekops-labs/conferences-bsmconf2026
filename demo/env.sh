#!/usr/bin/env bash
# Shared paths and settings for the demo helper scripts in this directory.
# Source this file. Do not run it directly.

set -u

DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$(cd "$DEMO_DIR/../.." && pwd)/wanted"

WANTED_ENGINE="$WORKSPACE/wanted-engine"
DEPUTY_REPO="$WORKSPACE/deputy"
WSIGN_REPO="$WORKSPACE/wsign"
WORK="$WORKSPACE/demo-work"

DEPUTY="$DEPUTY_REPO/deputy"
WSIGN="$WSIGN_REPO/bin/wsign"

# Port 5000 is macOS's AirPlay Receiver. Set REGISTRY_PORT to override.
REGISTRY_PORT="${REGISTRY_PORT:-5001}"
REGISTRY="localhost:$REGISTRY_PORT"

IMAGE_SIGNING_KEY="$WANTED_ENGINE/keys/image-signing-demo.pem"
DEPUTY_SEED_FILE="$WANTED_ENGINE/keys/deputy-signing-seed.hex"
DEVICE_ID_FILE="$WORK/device-id"

mkdir -p "$WORK"

# find_port and list_ports.
source "$DEMO_DIR/macos-ports.sh"

require_device_id() {
    if [ ! -f "$DEVICE_ID_FILE" ]; then
        echo "No enrolled device on record. Run enrol.sh first." >&2
        exit 1
    fi
    cat "$DEVICE_ID_FILE"
}
