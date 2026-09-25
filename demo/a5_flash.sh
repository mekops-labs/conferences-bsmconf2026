#!/usr/bin/env bash
# Flash firmware onto the board over SWD, through the Debug Probe.
#
# Usage: flash.sh [path-to-nuttx-elf]
# Default: wanted-engine/third_party/nuttx/nuttx

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

ELF="${1:-$WANTED_ENGINE/third_party/nuttx/nuttx}"

if [ ! -f "$ELF" ]; then
    echo "ELF not found: $ELF" >&2
    echo "Build it first with: make defconfig rp2350_feather_sheriff && NUTTX_CLEAN=1 make build" >&2
    exit 1
fi

probe-rs download --chip RP2350 --binary-format elf "$ELF"
