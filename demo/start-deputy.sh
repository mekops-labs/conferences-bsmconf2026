#!/usr/bin/env bash
# Starts the control plane in a loop (restarting board makes serial port
# disappear, so we need to loop).

set -u
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

REQUIRE_FLAG="--require-signed-images"
if [ "${1:-}" = "--unenforced" ]; then
    REQUIRE_FLAG=""
    echo "Starting WITHOUT --require-signed-images." >&2
fi

export DEPUTY_IMAGE_SIGNING_KEYS="1:$("$WSIGN" pubkey --key "$IMAGE_SIGNING_KEY")"

while true; do
    BOARD=$(find_port 0525) && \
        "$DEPUTY" server --serial "$BOARD" --listen 127.0.0.1:8080 \
            --signing-seed="$(cat "$DEPUTY_SEED_FILE")" \
            --db "$WORK/deputy.db" --layer-cache "$WORK/layers" \
            --registry-address "$REGISTRY" --oci-insecure $REQUIRE_FLAG
    sleep 0.5
done
