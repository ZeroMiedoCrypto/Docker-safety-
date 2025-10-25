#!/bin/bash
set -euo pipefail

cleanup() {
    if command -v tigervncserver >/dev/null 2>&1; then
        tigervncserver -kill :1 >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

log() {
    echo "[safeopen] $*"
}

apply_firewall() {
    log "Configuring egress firewall policies"
    iptables -F
    iptables -P OUTPUT DROP
    iptables -P INPUT DROP
    iptables -P FORWARD DROP

    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT

    # Allow established/related inbound for VNC responses
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # Allow DNS queries
    iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

    # Allow HTTPS traffic
    iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

    # Explicitly block private networks
    for range in 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
        iptables -A OUTPUT -d "$range" -j REJECT
    done

    # Allow VNC server to expose port 5901 to host user
    iptables -A INPUT -p tcp --dport 5901 -j ACCEPT
}

start_vnc_environment() {
    local password="$1"

    log "Starting virtual desktop with TigerVNC"

    if ! id safeuser >/dev/null 2>&1; then
        useradd --create-home safeuser
    fi

    su - safeuser -c "mkdir -p ~/.vnc"
    su - safeuser -c "printf '%s\n' '$password' | vncpasswd -f > ~/.vnc/passwd"
    su - safeuser -c "chmod 600 ~/.vnc/passwd"

    # Launch a lightweight window manager and VNC server
    su - safeuser -c "dbus-launch tigervncserver :1 -localhost no -SecurityTypes VncAuth -fg" &
    VNC_PID=$!
    # Give the server a moment to start
    sleep 2

    su - safeuser -c "DISPLAY=:1 fluxbox" &
    WM_PID=$!
    sleep 2
}

launch_target() {
    local target_type="$1"
    local target_value="$2"
    local log_dir="$3"

    mkdir -p "$log_dir"

    case "$target_type" in
        url)
            log "Launching Chromium with URL $target_value"
            su - safeuser -c "DISPLAY=:1 chromium --no-first-run --no-default-browser-check --disable-dev-shm-usage --user-data-dir=/home/safeuser/.config/chromium '$target_value'"
            ;;
        file)
            if [ ! -f "$target_value" ]; then
                log "Provided file $target_value not found inside container"
                exit 1
            fi
            local working_copy="/tmp/${RANDOM}_$(basename "$target_value")"
            cp "$target_value" "$working_copy"
            log "Scanning file with ClamAV"
            set +e
            clamscan --infected --no-summary "$working_copy"
            local scan_status=$?
            set -e
            if [ $scan_status -ne 0 ]; then
                log "ClamAV detected a threat or scan failed (status $scan_status)."
                rm -f "$working_copy"
                exit $scan_status
            fi
            log "Launching Chromium with local file"
            su - safeuser -c "DISPLAY=:1 chromium --no-first-run --no-default-browser-check --disable-dev-shm-usage --user-data-dir=/home/safeuser/.config/chromium 'file://$working_copy'"
            rm -f "$working_copy"
            ;;
        *)
            log "Unknown target type: $target_type"
            exit 1
            ;;
    esac
}

main() {
    local target_type="${SAFEOPEN_TARGET_TYPE:-}"
    local target_value="${SAFEOPEN_TARGET_VALUE:-}"
    local log_dir="${SAFEOPEN_LOG_DIR:-/var/safe_logs}"
    local vnc_password="${SAFEOPEN_VNC_PASSWORD:-changeme}"

    if [[ -z "$target_type" || -z "$target_value" ]]; then
        echo "safeopen container invoked without target context" >&2
        exit 1
    fi

    mkdir -p "$log_dir"

    apply_firewall
    start_vnc_environment "$vnc_password"
    mkdir -p /var/lib/clamav /var/log/clamav
    if [ "$target_type" = "file" ]; then
        log "Refreshing ClamAV signatures"
        freshclam --stdout --quiet || log "freshclam update failed"
    fi
    launch_target "$target_type" "$target_value" "$log_dir"
}

main "$@"
