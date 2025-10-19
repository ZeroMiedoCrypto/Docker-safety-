#!/bin/bash
# Cleanup script for secure container
# Removes temporary files, browser cache, and sensitive data

set -euo pipefail

echo "[Cleanup] Starting cleanup process..."

# Remove browser profile and cache
if [[ -d /tmp/chromium-profile ]]; then
    echo "[Cleanup] Removing Chromium profile..."
    rm -rf /tmp/chromium-profile
fi

# Remove temporary files
if [[ -d /tmp/safeopen ]]; then
    echo "[Cleanup] Removing temporary files..."
    rm -rf /tmp/safeopen/*
fi

# Remove XDG runtime files
if [[ -d /tmp/runtime-safeuser ]]; then
    echo "[Cleanup] Removing runtime files..."
    rm -rf /tmp/runtime-safeuser/*
fi

# Clear bash history for safeuser
if [[ -f /home/safeuser/.bash_history ]]; then
    echo "[Cleanup] Clearing bash history..."
    rm -f /home/safeuser/.bash_history
fi

# Remove any downloaded files (if download directory exists)
if [[ -d /home/safeuser/Downloads ]]; then
    echo "[Cleanup] Removing downloads..."
    rm -rf /home/safeuser/Downloads/*
fi

# Securely wipe sensitive files (overwrite with random data)
secure_wipe() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
        dd if=/dev/urandom of="$file" bs=1 count="$size" conv=notrunc 2>/dev/null || true
        rm -f "$file"
    fi
}

# Find and wipe any sensitive files (optional - can be customized)
# secure_wipe /tmp/sensitive-file.txt

echo "[Cleanup] Cleanup complete"
echo "[Cleanup] Container is ready for destruction"

# Exit with success
exit 0
