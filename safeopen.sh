#!/bin/bash
# SafeOpen - Secure Disposable Container Launcher for macOS
# Provides a simple CLI interface to launch secure browsing containers

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="safeopen:latest"
CONTAINER_PREFIX="safeopen"
LOG_DIR="${HOME}/.safeopen/logs"
TMP_DIR="/tmp/safeopen"
MAX_STARTUP_WAIT=30  # seconds

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}          ${GREEN}SafeOpen - Secure Browser${NC}                 ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
}

log() {
    echo -e "${GREEN}[SafeOpen]${NC} $1"
}

error() {
    echo -e "${RED}[Error]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[Warning]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker Desktop for macOS."
        error "Download from: https://www.docker.com/products/docker-desktop"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running. Please start Docker Desktop."
        exit 1
    fi
    
    # Check Docker version
    local docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
    log "Docker version: $docker_version"
    
    # Create necessary directories
    mkdir -p "$LOG_DIR" "$TMP_DIR"
}

# Build or update Docker image
build_image() {
    log "Checking for Docker image: $IMAGE_NAME"
    
    if docker image inspect "$IMAGE_NAME" &> /dev/null; then
        log "Image found. Use --rebuild to force rebuild."
    else
        log "Image not found. Building now..."
        rebuild_image
    fi
}

# Force rebuild Docker image
rebuild_image() {
    log "Building Docker image (this may take a few minutes)..."
    
    if docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"; then
        log "✓ Image built successfully"
    else
        error "Failed to build Docker image"
        exit 1
    fi
}

# Generate unique container name
generate_container_name() {
    echo "${CONTAINER_PREFIX}_$(date +%s)_$$"
}

# Cleanup function
cleanup_container() {
    local container_name="$1"
    
    log "Cleaning up container: $container_name"
    
    # Stop container if running
    docker stop "$container_name" 2>/dev/null || true
    
    # Remove container
    docker rm -f "$container_name" 2>/dev/null || true
    
    log "✓ Cleanup complete"
}

# Clean old containers
cleanup_old_containers() {
    log "Cleaning up old SafeOpen containers..."
    
    local count=0
    for container in $(docker ps -a --filter "name=${CONTAINER_PREFIX}_" --format "{{.Names}}"); do
        docker rm -f "$container" 2>/dev/null || true
        ((count++))
    done
    
    if [[ $count -gt 0 ]]; then
        log "✓ Removed $count old container(s)"
    else
        log "No old containers to clean"
    fi
}

# Open URL in secure container
open_url() {
    local url="$1"
    local container_name=$(generate_container_name)
    
    log "Opening URL: $url"
    log "Container: $container_name"
    
    # Create log entry
    echo "$(date -Iseconds)|URL|$url|$container_name" >> "$LOG_DIR/access.log"
    
    # Run container
    docker run --rm \
        --name "$container_name" \
        --security-opt=no-new-privileges:true \
        --cap-drop=ALL \
        --read-only \
        --tmpfs /tmp:rw,noexec,nosuid,size=512m \
        --tmpfs /home/safeuser:rw,noexec,nosuid,size=256m \
        -v "$LOG_DIR:/var/safe_logs:rw" \
        --network bridge \
        --dns 8.8.8.8 \
        --dns 8.8.4.4 \
        -e SAFEOPEN_ENABLE_VNC=false \
        "$IMAGE_NAME" \
        --url "$url"
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log "✓ Session completed successfully"
    else
        error "Session ended with errors (exit code: $exit_code)"
    fi
    
    return $exit_code
}

# Open file in secure container
open_file() {
    local file_path="$1"
    local container_name=$(generate_container_name)
    
    # Resolve absolute path
    file_path=$(cd "$(dirname "$file_path")" && pwd)/$(basename "$file_path")
    
    if [[ ! -f "$file_path" ]]; then
        error "File not found: $file_path"
        exit 1
    fi
    
    local file_name=$(basename "$file_path")
    local file_size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null)
    
    log "Opening file: $file_name ($(numfmt --to=iec-i --suffix=B $file_size 2>/dev/null || echo "$file_size bytes"))"
    log "Container: $container_name"
    
    # Calculate hash for logging
    local file_hash=$(shasum -a 256 "$file_path" | awk '{print $1}')
    
    # Create log entry
    echo "$(date -Iseconds)|FILE|$file_name|$file_hash|$container_name" >> "$LOG_DIR/access.log"
    
    # Copy file to temporary location (will be mounted into container)
    local temp_file="$TMP_DIR/$file_name"
    cp "$file_path" "$temp_file"
    
    # Run container with file mount
    docker run --rm \
        --name "$container_name" \
        --security-opt=no-new-privileges:true \
        --cap-drop=ALL \
        --read-only \
        --tmpfs /tmp:rw,noexec,nosuid,size=512m \
        --tmpfs /home/safeuser:rw,noexec,nosuid,size=256m \
        -v "$temp_file:/tmp/safeopen/$(basename "$file_path"):ro" \
        -v "$LOG_DIR:/var/safe_logs:rw" \
        --network bridge \
        --dns 8.8.8.8 \
        --dns 8.8.4.4 \
        -e SAFEOPEN_ENABLE_VNC=false \
        "$IMAGE_NAME" \
        --file "/tmp/safeopen/$(basename "$file_path")"
    
    local exit_code=$?
    
    # Clean up temporary file
    rm -f "$temp_file"
    
    if [[ $exit_code -eq 0 ]]; then
        log "✓ Session completed successfully"
    else
        error "Session ended with errors (exit code: $exit_code)"
    fi
    
    return $exit_code
}

# Scan file only (no opening)
scan_file() {
    local file_path="$1"
    local container_name=$(generate_container_name)
    
    # Resolve absolute path
    file_path=$(cd "$(dirname "$file_path")" && pwd)/$(basename "$file_path")
    
    if [[ ! -f "$file_path" ]]; then
        error "File not found: $file_path"
        exit 1
    fi
    
    local file_name=$(basename "$file_path")
    
    log "Scanning file: $file_name"
    
    # Copy file to temporary location
    local temp_file="$TMP_DIR/$file_name"
    cp "$file_path" "$temp_file"
    
    # Run container with scan-only mode
    docker run --rm \
        --name "$container_name" \
        --security-opt=no-new-privileges:true \
        --cap-drop=ALL \
        --read-only \
        --tmpfs /tmp:rw,noexec,nosuid,size=512m \
        -v "$temp_file:/tmp/safeopen/$(basename "$file_path"):ro" \
        -v "$LOG_DIR:/var/safe_logs:rw" \
        --network none \
        "$IMAGE_NAME" \
        --scan-only "/tmp/safeopen/$(basename "$file_path")"
    
    local exit_code=$?
    
    # Clean up temporary file
    rm -f "$temp_file"
    
    return $exit_code
}

# Display help
show_help() {
    cat << EOF
SafeOpen - Secure Disposable Container for Safe Browsing

USAGE:
    safeopen [OPTIONS] <target>

ARGUMENTS:
    <target>    URL (http://... or https://...) or file path to open

OPTIONS:
    --url <URL>         Explicitly open a URL
    --file <PATH>       Explicitly open a file
    --scan <PATH>       Scan file without opening
    --rebuild           Rebuild Docker image before launching
    --cleanup           Remove all old SafeOpen containers
    --logs              Show recent session logs
    --help, -h          Show this help message

EXAMPLES:
    # Open a URL
    safeopen https://example.com
    safeopen --url https://suspicious-site.com

    # Open and scan a file
    safeopen ~/Downloads/document.pdf
    safeopen --file ./attachment.html

    # Scan file without opening
    safeopen --scan ~/Downloads/suspicious.exe

    # Maintenance
    safeopen --rebuild    # Rebuild Docker image
    safeopen --cleanup    # Clean old containers
    safeopen --logs       # View session logs

SECURITY FEATURES:
    ✓ Isolated container environment
    ✓ ClamAV malware scanning for files
    ✓ Restricted network access
    ✓ Non-root user execution
    ✓ Read-only host mounts
    ✓ Automatic cleanup after session
    ✓ SHA256 hash logging

LOGS:
    Session logs: ~/.safeopen/logs/access.log
    Scan results: ~/.safeopen/logs/session.log

For more information, visit: https://github.com/yourusername/safeopen

EOF
}

# Show recent logs
show_logs() {
    if [[ -f "$LOG_DIR/access.log" ]]; then
        log "Recent session logs:"
        tail -n 20 "$LOG_DIR/access.log"
    else
        log "No logs found"
    fi
}

# Main function
main() {
    # Parse arguments
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    case "${1:-}" in
        --help|-h)
            show_help
            ;;
        --rebuild)
            print_header
            check_prerequisites
            rebuild_image
            ;;
        --cleanup)
            print_header
            check_prerequisites
            cleanup_old_containers
            ;;
        --logs)
            show_logs
            ;;
        --url)
            if [[ -z "${2:-}" ]]; then
                error "URL required"
                exit 1
            fi
            print_header
            check_prerequisites
            build_image
            open_url "$2"
            ;;
        --file)
            if [[ -z "${2:-}" ]]; then
                error "File path required"
                exit 1
            fi
            print_header
            check_prerequisites
            build_image
            open_file "$2"
            ;;
        --scan)
            if [[ -z "${2:-}" ]]; then
                error "File path required"
                exit 1
            fi
            print_header
            check_prerequisites
            build_image
            scan_file "$2"
            ;;
        *)
            # Auto-detect URL or file
            local target="$1"
            print_header
            check_prerequisites
            build_image
            
            if [[ "$target" =~ ^https?:// ]]; then
                open_url "$target"
            elif [[ -f "$target" ]]; then
                open_file "$target"
            else
                error "Invalid target. Must be a URL or existing file path."
                echo ""
                show_help
                exit 1
            fi
            ;;
    esac
}

# Run main function
main "$@"
