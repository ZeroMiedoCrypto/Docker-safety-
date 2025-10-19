#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="safeopen:latest"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/.safeopen/logs"
APPARMOR_PROFILE="$ROOT_DIR/config/apparmor/safeopen-chromium"
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
CONTAINER_NAME="safeopen-$(date +%s)-$RANDOM"
TARGET="${1:-}"
TEMP_DIR=""
LOG_FILE="$LOG_DIR/${TIMESTAMP//:/-}.log"

usage() {
    cat <<USAGE
Usage: $(basename "$0") [target]
  target  Optional file path or URL to open in the isolated Chromium session.
USAGE
}

cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

mkdir -p "$LOG_DIR"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "docker command not found" >&2
    exit 1
fi

if ! command -v clamscan >/dev/null 2>&1; then
    echo "clamscan command not found" >&2
    exit 1
fi

if [ -f "$APPARMOR_PROFILE" ] && command -v apparmor_parser >/dev/null 2>&1; then
    if command -v sudo >/dev/null 2>&1; then
        if sudo -n true >/dev/null 2>&1; then
            sudo apparmor_parser -r "$APPARMOR_PROFILE"
        else
            echo "sudo privileges required to load AppArmor profile" >&2
            sudo apparmor_parser -r "$APPARMOR_PROFILE"
        fi
    else
        echo "sudo not found; unable to load AppArmor profile automatically" >&2
    fi
fi

echo "[safeopen] Building container image..."
docker build --pull -t "$IMAGE_TAG" "$ROOT_DIR" >/dev/null

MOUNT_ARGS=()
ENV_ARGS=()
SCAN_RESULT="clean"
HASH_VALUE="-"

if [ -n "$TARGET" ]; then
    if [ -f "$TARGET" ]; then
        REAL_PATH="$(readlink -f "$TARGET")"
        TEMP_DIR="$(mktemp -d)"
        BASENAME="$(basename "$REAL_PATH")"
        cp "$REAL_PATH" "$TEMP_DIR/$BASENAME"
        echo "[safeopen] Scanning file with ClamAV..."
        if ! clamscan --no-summary "$REAL_PATH"; then
            STATUS=$?
            if [ "$STATUS" -eq 1 ]; then
                SCAN_RESULT="infected"
                echo "[safeopen] ClamAV detected malware in $REAL_PATH" >&2
            else
                SCAN_RESULT="error"
                echo "[safeopen] ClamAV scan failed with status $STATUS" >&2
            fi
            printf '%s target="%s" hash=%s result=%s\n' "$TIMESTAMP" "$REAL_PATH" "-" "$SCAN_RESULT" >> "$LOG_FILE"
            exit 2
        fi
        HASH_VALUE="$(sha256sum "$REAL_PATH" | awk '{print $1}')"
        MOUNT_ARGS+=("--mount" "type=bind,source=$TEMP_DIR/$BASENAME,target=/safeopen/input/$BASENAME,readonly")
        ENV_ARGS+=("-e" "SAFEOPEN_TARGET=/safeopen/input/$BASENAME")
    else
        ENV_ARGS+=("-e" "SAFEOPEN_TARGET=$TARGET")
    fi
else
    ENV_ARGS+=("-e" "SAFEOPEN_TARGET=about:blank")
fi

printf '%s target="%s" hash=%s result=%s\n' "$TIMESTAMP" "${TARGET:-(none)}" "$HASH_VALUE" "$SCAN_RESULT" >> "$LOG_FILE"

echo "[safeopen] Starting isolated Chromium container (name: $CONTAINER_NAME)"

DOCKER_ARGS=(
    --rm=false
    --name "$CONTAINER_NAME"
    --read-only
    --tmpfs /tmp:rw,noexec,nosuid,size=512m
    --tmpfs /run:rw,noexec,nosuid,size=64m
    --mount type=tmpfs,destination=/home/safeuser/.cache
    --cap-drop=ALL
    --security-opt apparmor=safeopen-chromium
    --pids-limit=256
    --memory=1g
    --cpus=2
    --network=none
    --userns=keep-id
)

if [ ${#MOUNT_ARGS[@]} -gt 0 ]; then
    DOCKER_ARGS+=("${MOUNT_ARGS[@]}")
fi

if [ ${#ENV_ARGS[@]} -gt 0 ]; then
    DOCKER_ARGS+=("${ENV_ARGS[@]}")
fi

docker run "${DOCKER_ARGS[@]}" "$IMAGE_TAG"
EXIT_STATUS=$?

if [ $EXIT_STATUS -ne 0 ]; then
    echo "[safeopen] Container exited with status $EXIT_STATUS" >&2
fi

cleanup
trap - EXIT
exit $EXIT_STATUS
