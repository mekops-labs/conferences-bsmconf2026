#!/usr/bin/env bash
# List images and tags in the local demo registry.
#
# Usage: registry-list.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

repos=$(curl -sf "http://$REGISTRY/v2/_catalog" | python3 -c "
import json, sys
print('\n'.join(json.load(sys.stdin).get('repositories', [])))
")

if [ -z "$repos" ]; then
    echo "No images in $REGISTRY."
    exit 0
fi

while IFS= read -r repo; do
    [ -z "$repo" ] && continue
    tags=$(curl -sf "http://$REGISTRY/v2/$repo/tags/list" | python3 -c "
import json, sys
print('\n'.join(sorted(json.load(sys.stdin).get('tags') or [])))
")
    echo "$repo"
    while IFS= read -r tag; do
        [ -z "$tag" ] && continue
        case "$tag" in
            *.wanted-sig) echo "    $tag  (signature)" ;;
            *)            echo "    $tag" ;;
        esac
    done <<< "$tags"
done <<< "$repos"
