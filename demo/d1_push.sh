#!/usr/bin/env bash
# Push a wapp to the enrolled device.
#
# Usage: push.sh <name> <version> <image:tag> [policy-json]
# Example: push.sh rogue 1.0.0 rogue:1.0.0

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

if [ "$#" -ne 3 ] && [ "$#" -ne 4 ]; then
    echo "Usage: push.sh <name> <version> <image:tag> [policy-json]" >&2
    exit 1
fi

NAME="$1"
VERSION="$2"
IMAGE="$3"
POLICY="${4:-}"
DEVICE_ID=$(require_device_id)

WSH_POLICY='{"drivers":[{"name":"wanted"},{"name":"log","path":"/logs","options":"name=supervisor"},{"name":"gpio","options":"pins=led:/dev/gpio7:out"}],"console":{"out":{"name":"platform"},"in":{"name":"platform"}}}'

if [ -z "$POLICY" ] && [ "$NAME" = "wsh" ]; then
    POLICY="$WSH_POLICY"
fi

if [ -n "$POLICY" ]; then
    "$DEPUTY" device wapp create --version="$VERSION" --image="$REGISTRY/$IMAGE" --policy="$POLICY" "$DEVICE_ID" "$NAME"
else
    "$DEPUTY" device wapp create --version="$VERSION" --image="$REGISTRY/$IMAGE" "$DEVICE_ID" "$NAME"
fi
