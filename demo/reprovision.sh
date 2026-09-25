#!/usr/bin/env bash
# Force the board back to "no device identity", so the provisioning prompt
# shows again. Firmware and keys stay untouched — only the identity volume
# is cleared. Run c1_enrol.sh afterward.

set -euo pipefail

FLASH_ADDR=0x10682000
WIPE_BYTES=8192
TMP_BIN="$(mktemp -t reprovision-wipe)"
trap 'rm -f "$TMP_BIN"' EXIT

dd if=/dev/zero of="$TMP_BIN" bs=1 count="$WIPE_BYTES" >/dev/null 2>&1

probe-rs download --chip RP2350 --binary-format bin \
    --base-address "$FLASH_ADDR" "$TMP_BIN"
probe-rs reset --chip RP2350

echo "Identity volume cleared. Run c1_enrol.sh next."
