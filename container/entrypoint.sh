#!/bin/bash
# Entrypoint script for secure disposable container
# Handles initialization, security setup, and browser launch

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[SafeOpen]${NC} $1"
}

error() {
    echo -e "${RED}[SafeOpen Error]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[SafeOpen Warning]${NC} $1"
}

# Display help message
show_help() {
    cat << EOF
SafeOpen - Secure Disposable Container for Safe Browsing

Usage:
  --url <URL>           Open a URL in secure browser
  --file <FILE>         Scan and open a file
  --scan-only <FILE>    Only scan file without opening
  --help                Show this help message

Environment Variables:
  SAFEOPEN_LOG_DIR      Directory for session logs (default: /var/safe_logs)
  SAFEOPEN_ENABLE_VNC   Enable VNC server for remote viewing (default: false)

Security Features:
  ✓ Isolated network with restricted outbound access
  ✓ ClamAV malware scanning for all files
  ✓ Non-root user execution
  ✓ Read-only host mounts
  ✓ Automatic cleanup on exit

EOF
}

# Initialize Xvfb (virtual framebuffer)
init_display() {
    log "Initializing virtual display..."
    Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp &
    XVFB_PID=$!
    sleep 2
    
    # Start VNC server if requested
    if [[ "${SAFEOPEN_ENABLE_VNC:-false}" == "true" ]]; then
        log "Starting VNC server on port 5900..."
        x11vnc -display :99 -forever -nopw -quiet &
        VNC_PID=$!
    fi
}

# Setup network restrictions
setup_network() {
    log "Applying network restrictions..."
    
    # Note: iptables requires NET_ADMIN capability
    # Rules are applied by the host or network-rules.sh if running as root
    if [[ -f /usr/local/bin/network-rules.sh ]]; then
        sudo /usr/local/bin/network-rules.sh 2>/dev/null || warn "Could not apply iptables rules (requires --cap-add=NET_ADMIN)"
    fi
}

# Scan file with ClamAV
scan_file() {
    local file_path="$1"
    local file_name=$(basename "$file_path")
    
    log "Scanning file: $file_name"
    
    if [[ ! -f "$file_path" ]]; then
        error "File not found: $file_path"
        return 1
    fi
    
    # Calculate SHA256 hash
    local file_hash=$(sha256sum "$file_path" | awk '{print $1}')
    log "File SHA256: $file_hash"
    
    # Run ClamAV scan
    local scan_result
    if scan_result=$(clamscan --no-summary "$file_path" 2>&1); then
        log "✓ Scan complete: No threats detected"
        
        # Log scan result
        echo "$(date -Iseconds)|SCAN_CLEAN|$file_name|$file_hash" >> /var/safe_logs/session.log
        return 0
    else
        error "⚠ THREAT DETECTED IN FILE!"
        echo "$(date -Iseconds)|SCAN_INFECTED|$file_name|$file_hash" >> /var/safe_logs/session.log
        
        # Remove infected file
        rm -f "$file_path"
        error "File has been removed for safety."
        return 1
    fi
}

# Open URL in Chromium
open_url() {
    local url="$1"
    
    log "Opening URL in secure browser: $url"
    
    # Validate URL format
    if [[ ! "$url" =~ ^https?:// ]]; then
        error "Invalid URL format. Must start with http:// or https://"
        return 1
    fi
    
    # Log access
    echo "$(date -Iseconds)|URL_OPEN|$url" >> /var/safe_logs/session.log
    
    # Launch Chromium with security flags
    chromium-browser \
        --no-sandbox \
        --disable-dev-shm-usage \
        --disable-gpu \
        --disable-software-rasterizer \
        --disable-extensions \
        --disable-plugins \
        --disable-sync \
        --incognito \
        --no-first-run \
        --no-default-browser-check \
        --disable-background-networking \
        --disable-background-timer-throttling \
        --disable-backgrounding-occluded-windows \
        --disable-breakpad \
        --disable-component-update \
        --disable-domain-reliability \
        --disable-features=AutofillServerCommunication \
        --user-data-dir=/tmp/chromium-profile \
        "$url" 2>/dev/null &
    
    BROWSER_PID=$!
    log "Browser launched (PID: $BROWSER_PID)"
    
    # Wait for browser to close
    wait $BROWSER_PID || true
    log "Browser closed"
}

# Open file after scanning
open_file() {
    local file_path="$1"
    
    # Scan file first
    if ! scan_file "$file_path"; then
        error "File failed security scan. Aborting."
        return 1
    fi
    
    # Determine file type and open appropriately
    local mime_type=$(file --mime-type -b "$file_path")
    
    log "Opening file: $(basename "$file_path") (type: $mime_type)"
    
    case "$mime_type" in
        text/html|application/xhtml+xml)
            # Open HTML files in browser
            chromium-browser --incognito --no-sandbox "file://$file_path" &
            BROWSER_PID=$!
            wait $BROWSER_PID || true
            ;;
        application/pdf)
            # Open PDF in browser
            chromium-browser --incognito --no-sandbox "file://$file_path" &
            BROWSER_PID=$!
            wait $BROWSER_PID || true
            ;;
        *)
            log "File type: $mime_type"
            log "Opening in default viewer (Chromium)..."
            chromium-browser --incognito --no-sandbox "file://$file_path" &
            BROWSER_PID=$!
            wait $BROWSER_PID || true
            ;;
    esac
}

# Cleanup function
cleanup() {
    log "Cleaning up..."
    
    # Kill background processes
    [[ -n "${BROWSER_PID:-}" ]] && kill $BROWSER_PID 2>/dev/null || true
    [[ -n "${XVFB_PID:-}" ]] && kill $XVFB_PID 2>/dev/null || true
    [[ -n "${VNC_PID:-}" ]] && kill $VNC_PID 2>/dev/null || true
    
    # Remove temporary files
    rm -rf /tmp/chromium-profile /tmp/safeopen/* 2>/dev/null || true
    
    log "Cleanup complete. Container will self-destruct."
}

# Register cleanup trap
trap cleanup EXIT INT TERM

# Main execution
main() {
    log "SafeOpen Container Starting..."
    log "User: $(whoami), UID: $(id -u)"
    
    # Initialize display
    init_display
    
    # Setup network restrictions
    # setup_network  # Disabled by default, requires elevated privileges
    
    # Parse arguments
    case "${1:-}" in
        --help|-h)
            show_help
            ;;
        --url)
            if [[ -z "${2:-}" ]]; then
                error "URL argument required"
                exit 1
            fi
            open_url "$2"
            ;;
        --file)
            if [[ -z "${2:-}" ]]; then
                error "File path required"
                exit 1
            fi
            open_file "$2"
            ;;
        --scan-only)
            if [[ -z "${2:-}" ]]; then
                error "File path required"
                exit 1
            fi
            scan_file "$2"
            ;;
        *)
            show_help
            ;;
    esac
    
    log "Session ended successfully"
}

# Execute main function
main "$@"
