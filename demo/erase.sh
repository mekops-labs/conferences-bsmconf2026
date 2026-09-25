#!/usr/bin/env bash
# Erase the board's entire flash chip: firmware, identity, and wapps.
# Use this only to force a new enrolment on a board that already has one.
# Takes a lot of time!

set -euo pipefail

echo "This erases the entire flash chip, including firmware."
read -r -p "Continue? [y/N] " reply
case "$reply" in
    [yY]) ;;
    *) echo "Cancelled." >&2; exit 1 ;;
esac

probe-rs erase --chip RP2350
