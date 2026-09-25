#!/usr/bin/env bash
#
# Usage:
#   ./macos-ports.sh              # list every USB-serial port found
#   source ./macos-ports.sh
#   find_port 0525                # print the /dev/cu.usbmodemNNNN for that
#                                  # vendor id, exit 1 if none is attached

find_port() {
    local vendor_dec=$((16#$1))
    ioreg -c IOUSBHostDevice -r -l | awk -v vendor="$vendor_dec" '
        /"idVendor"/ { match($0, /[0-9]+/); v = substr($0, RSTART, RLENGTH) + 0 }
        /"IOCalloutDevice"/ {
            if (v == vendor) {
                match($0, /\/dev\/[^"]+/)
                print substr($0, RSTART, RLENGTH)
                found = 1
            }
        }
        END { exit(found ? 0 : 1) }
    '
}

list_ports() {
    ioreg -c IOUSBHostDevice -r -l | awk '
        /"idVendor"/          { match($0, /[0-9]+/); v = substr($0, RSTART, RLENGTH) + 0 }
        /"idProduct"/         { match($0, /[0-9]+/); p = substr($0, RSTART, RLENGTH) + 0 }
        /"USB Vendor Name"/   { match($0, /"[^"]*"$/); vname = substr($0, RSTART + 1, RLENGTH - 2) }
        /"USB Product Name"/  { match($0, /"[^"]*"$/); pname = substr($0, RSTART + 1, RLENGTH - 2) }
        /"IOCalloutDevice"/ {
            match($0, /\/dev\/[^"]+/)
            path = substr($0, RSTART, RLENGTH)
            printf "%-22s %04x:%04x  %s %s\n", path, v, p, vname, pname
        }
    '
}

# Run list_ports when executed directly; only define the functions when sourced.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    list_ports
fi
