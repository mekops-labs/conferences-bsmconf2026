#!/usr/bin/env bash
# Sign an image already pushed to the registry, and publish the signature
# beside it.
#
# Usage: sign.sh <image:tag>
# Example: sign.sh wsh:0.5.0

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

if [ "$#" -ne 1 ]; then
    echo "Usage: sign.sh <image:tag>" >&2
    exit 1
fi

"$WSIGN" publish --insecure --key "$IMAGE_SIGNING_KEY" --key-id 1 "$REGISTRY/$1"
