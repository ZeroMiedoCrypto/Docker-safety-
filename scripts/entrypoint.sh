#!/usr/bin/env bash
set -euo pipefail

# Ensure clamav database exists inside the container for optional scans
if [ -f /etc/clamav/freshclam.conf ]; then
    mkdir -p /var/lib/clamav
    freshclam --quiet || true
fi

if [ -x /opt/safeopen/config/network/lockdown.sh ]; then
    /opt/safeopen/config/network/lockdown.sh
fi

TARGET=${SAFEOPEN_TARGET:-about:blank}
PROFILE_ROOT="/tmp/safeopen"
mkdir -p "$PROFILE_ROOT"
chown "$SAFEOPEN_USER:$SAFEOPEN_USER" "$PROFILE_ROOT"

cleanup() {
    if pgrep -u "$SAFEOPEN_USER" Xtigervnc > /dev/null 2>&1; then
        pkill -u "$SAFEOPEN_USER" Xtigervnc || true
    fi
    if [ -f "$PROFILE_ROOT/.Xauthority" ]; then
        rm -f "$PROFILE_ROOT/.Xauthority"
    fi
}
trap cleanup EXIT

export USER="$SAFEOPEN_USER"
export HOME="$SAFEOPEN_HOME"
export PROFILE_ROOT

exec gosu "$SAFEOPEN_USER" /opt/safeopen/scripts/start-chromium.sh "$TARGET"
