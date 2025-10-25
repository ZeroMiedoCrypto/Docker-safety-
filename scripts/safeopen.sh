#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="safeopen:latest"
LOG_ROOT="${HOME}/.safeopen/logs"
TMP_ROOT="/tmp/safeopen"

usage() {
    cat <<USAGE
Usage: safeopen <url|file>

Launches the disposable safe browsing container for the provided URL or file.
USAGE
}

require_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo "Docker is required but was not found in PATH" >&2
        exit 1
    fi
}

build_image_if_needed() {
    if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        echo "[safeopen] Building container image..."
        docker build -t "$IMAGE_NAME" .
    fi
}

create_temp_workspace() {
    local id="$1"
    local dir="${TMP_ROOT}/${id}"
    mkdir -p "$dir"
    echo "$dir"
}

cleanup_workspace() {
    local dir="$1"
    if [ -d "$dir" ]; then
        rm -rf "$dir"
    fi
}

is_url() {
    local value="$1"
    [[ "$value" =~ ^https?:// ]]
}

generate_password() {
    LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16
}

current_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

ensure_log_root() {
    mkdir -p "$LOG_ROOT"
}

log_event() {
    ensure_log_root
    local message="$1"
    local logfile="${LOG_ROOT}/$(date -u +%Y-%m-%d).log"
    printf '%s %s\n' "$(current_timestamp)" "$message" >> "$logfile"
}

hash_file() {
    local path="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$path" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$path" | awk '{print $1}'
    else
        echo "Unable to calculate SHA256 hash: no sha256sum or shasum" >&2
        echo ""
        return 0
    fi
}

append_linux_hardening_flags() {
    if [ "${SAFEOPEN_DISABLE_HARDENING:-0}" = "1" ]; then
        return
    fi

    if [[ "$(uname -s)" != "Darwin" ]]; then
        local security_options info_output
        security_options=$(docker info --format '{{json .SecurityOptions}}' 2>/dev/null || true)
        info_output=$(docker info --format '{{.SecurityOptions}}' 2>/dev/null || true)
        if [[ "$security_options" == *"apparmor"* ]]; then
            DOCKER_ARGS+=("--security-opt" "apparmor=safeopen")
        fi
        if [[ "$info_output" == *"userns"* ]]; then
            DOCKER_ARGS+=("--userns=keep-id")
        fi
    fi
}

main() {
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi

    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        usage
        exit 0
    fi

    if [ $# -ne 1 ]; then
        usage
        exit 1
    fi

    require_docker
    build_image_if_needed

    local target="$1"
    local session_id="$(date +%s)-$RANDOM"
    local workspace="$(create_temp_workspace "$session_id")"
    local container_name="safeopen-${session_id}"
    local vnc_password="$(generate_password)"
    local log_message=""

    ensure_log_root

    if is_url "$target"; then
        ENV_VARS+=("-e" "SAFEOPEN_TARGET_TYPE=url")
        ENV_VARS+=("-e" "SAFEOPEN_TARGET_VALUE=${target}")
        log_message="URL ${target}"
    else
        if [ ! -f "$target" ]; then
            echo "Target file not found: $target" >&2
            cleanup_workspace "$workspace"
            exit 1
        fi
        local filename
        filename="$(basename "$target")"
        local extension="${filename##*.}"
        local container_filename="payload"
        if [ -n "$extension" ] && [ "$extension" != "$filename" ]; then
            container_filename="${container_filename}.${extension}"
        fi
        local dest="${workspace}/${container_filename}"
        cp "$target" "$dest"
        local hash
        hash="$(hash_file "$target")"
        if [ -n "$hash" ]; then
            log_event "SHA256 ${hash} '${target}'"
        fi
        ENV_VARS+=("-e" "SAFEOPEN_TARGET_TYPE=file")
        ENV_VARS+=("-e" "SAFEOPEN_TARGET_VALUE=/safeopen/input/${container_filename}")
        DOCKER_ARGS+=("--mount" "type=bind,source=${workspace},target=/safeopen/input,readonly")
        log_message="FILE ${target}"
    fi

    ENV_VARS+=("-e" "SAFEOPEN_LOG_DIR=/var/safe_logs")
    ENV_VARS+=("-e" "SAFEOPEN_VNC_PASSWORD=${vnc_password}")

    DOCKER_ARGS+=("--rm")
    DOCKER_ARGS+=("--name" "$container_name")
    DOCKER_ARGS+=("-p" "5901:5901")
    DOCKER_ARGS+=("--cap-drop=ALL")
    DOCKER_ARGS+=("--security-opt" "no-new-privileges:true")
    DOCKER_ARGS+=("--pids-limit" "256")
    DOCKER_ARGS+=("--tmpfs" "/tmp:rw,noexec,nosuid,nodev")
    DOCKER_ARGS+=("--tmpfs" "/run:rw,noexec,nosuid,nodev")
    DOCKER_ARGS+=("--mount" "type=tmpfs,destination=/var/safe_logs")
    DOCKER_ARGS+=("--tmpfs" "/home/safeuser:rw,noexec,nosuid,nodev")
    DOCKER_ARGS+=("--tmpfs" "/var/lib/clamav:rw,noexec,nosuid,nodev")
    DOCKER_ARGS+=("--tmpfs" "/var/log/clamav:rw,noexec,nosuid,nodev")
    DOCKER_ARGS+=("--read-only")

    append_linux_hardening_flags

    echo "[safeopen] Starting disposable container ${container_name}" \
        "(connect to VNC on localhost:5901, password: ${vnc_password})"

    set +e
    docker run -it "${ENV_VARS[@]}" "${DOCKER_ARGS[@]}" "$IMAGE_NAME"
    local status=$?
    set -e

    cleanup_workspace "$workspace"

    if [ $status -eq 0 ]; then
        log_event "SUCCESS ${log_message}"
        echo "[safeopen] Session complete"
    else
        log_event "FAILURE ${log_message}"
        echo "[safeopen] Session failed" >&2
    fi

    exit $status
}

# Arrays need global scope for append_linux_hardening_flags
declare -a DOCKER_ARGS=()
declare -a ENV_VARS=()

main "$@"
