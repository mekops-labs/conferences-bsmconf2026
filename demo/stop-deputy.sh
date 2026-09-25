#!/usr/bin/env bash
# Stop the Deputy restart loop and any running Deputy server.

set -u

pkill -f 'start-deputy.sh' 2>/dev/null
pkill -f 'deputy server' 2>/dev/null
sleep 1

if lsof -nP -iTCP:8080 -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Port 8080 is still in use:" >&2
    lsof -nP -iTCP:8080 -sTCP:LISTEN >&2
    exit 1
fi

echo "Deputy stopped. Port 8080 is free."
