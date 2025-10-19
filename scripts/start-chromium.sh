#!/usr/bin/env bash
set -euo pipefail

TARGET=${1:-about:blank}
PROFILE_ROOT=${PROFILE_ROOT:-/tmp/safeopen}
CHROMIUM_BIN="$(command -v chromium-browser || command -v chromium || echo chromium-browser)"

if [ ! -x "$CHROMIUM_BIN" ]; then
    echo "Chromium binary not found" >&2
    exit 1
fi

export HOME="$SAFEOPEN_HOME"
export USER="$SAFEOPEN_USER"
mkdir -p "$PROFILE_ROOT"

if command -v tigervncserver >/dev/null 2>&1; then
    export DISPLAY=:1
    if ! pgrep -u "$SAFEOPEN_USER" Xtigervnc > /dev/null 2>&1; then
        tigervncserver :1 -localhost yes -geometry 1280x720 >/dev/null 2>&1
    fi
    cleanup() {
        tigervncserver -kill :1 >/dev/null 2>&1 || true
    }
    trap cleanup EXIT
    exec "$CHROMIUM_BIN" --no-sandbox --disable-gpu --user-data-dir="$PROFILE_ROOT/profile" "$TARGET"
else
    export DISPLAY=:99
    Xvfb :99 -screen 0 1280x720x24 >/tmp/xvfb.log 2>&1 &
    XVFB_PID=$!
    cleanup() {
        kill "$XVFB_PID" >/dev/null 2>&1 || true
        wait "$XVFB_PID" 2>/dev/null || true
    }
    trap cleanup EXIT
    exec "$CHROMIUM_BIN" --no-sandbox --disable-gpu --user-data-dir="$PROFILE_ROOT/profile" "$TARGET"
fi
