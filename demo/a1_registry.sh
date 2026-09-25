#!/usr/bin/env bash
# Runs local registry in a podman container

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

podman rm -f demo-registry >/dev/null 2>&1 || true
podman run -d --name demo-registry -p "$REGISTRY_PORT:5000" docker.io/library/registry:2
echo "Registry active at $REGISTRY"
