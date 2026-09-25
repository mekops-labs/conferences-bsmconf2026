#!/usr/bin/env bash
# Wrapper for deputy

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"


"$DEPUTY" $@
