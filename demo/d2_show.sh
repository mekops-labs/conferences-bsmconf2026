#!/usr/bin/env bash
# Show the enrolled device's current state.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

DEVICE_ID=$(require_device_id)
"$DEPUTY" device show "$DEVICE_ID"
