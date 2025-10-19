#!/bin/bash
# ClamAV scanner utility for file scanning
# Provides detailed scanning with hash calculation and logging

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
SCAN_LOG="/var/safe_logs/scan_results.log"
MAX_FILE_SIZE=$((100 * 1024 * 1024))  # 100 MB limit

# Initialize scanner
init_scanner() {
    echo -e "${GREEN}[Scanner]${NC} Initializing ClamAV..."
    
    # Check if ClamAV database is available
    if [[ ! -d /var/lib/clamav ]] || [[ -z "$(ls -A /var/lib/clamav 2>/dev/null)" ]]; then
        echo -e "${YELLOW}[Scanner]${NC} Updating virus definitions..."
        freshclam --quiet 2>/dev/null || true
    fi
    
    echo -e "${GREEN}[Scanner]${NC} Ready"
}

# Calculate file hash
calculate_hash() {
    local file="$1"
    sha256sum "$file" | awk '{print $1}'
}

# Get file metadata
get_metadata() {
    local file="$1"
    
    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    local type=$(file --mime-type -b "$file")
    local modified=$(stat -f%Sm -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || stat -c%y "$file" 2>/dev/null)
    
    echo "Size: $size bytes, Type: $type, Modified: $modified"
}

# Scan single file
scan_file() {
    local file="$1"
    local file_name=$(basename "$file")
    
    echo -e "${GREEN}[Scanner]${NC} =================================================="
    echo -e "${GREEN}[Scanner]${NC} Scanning: $file_name"
    
    # Check if file exists
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}[Scanner]${NC} Error: File not found"
        return 1
    fi
    
    # Check file size
    local file_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    if [[ $file_size -gt $MAX_FILE_SIZE ]]; then
        echo -e "${YELLOW}[Scanner]${NC} Warning: File exceeds maximum size ($MAX_FILE_SIZE bytes)"
        echo -e "${YELLOW}[Scanner]${NC} Skipping scan for large file"
        return 2
    fi
    
    # Get file metadata
    echo -e "${GREEN}[Scanner]${NC} Metadata: $(get_metadata "$file")"
    
    # Calculate hash
    local hash=$(calculate_hash "$file")
    echo -e "${GREEN}[Scanner]${NC} SHA256: $hash"
    
    # Run ClamAV scan
    echo -e "${GREEN}[Scanner]${NC} Running malware scan..."
    
    local scan_output
    local scan_status
    
    scan_output=$(clamscan --no-summary --infected "$file" 2>&1) || scan_status=$?
    scan_status=${scan_status:-0}
    
    if [[ $scan_status -eq 0 ]]; then
        echo -e "${GREEN}[Scanner]${NC} ✓ CLEAN - No threats detected"
        
        # Log result
        echo "$(date -Iseconds)|CLEAN|$file_name|$hash|$file_size" >> "$SCAN_LOG"
        return 0
    else
        echo -e "${RED}[Scanner]${NC} ⚠ INFECTED - Threat detected!"
        echo -e "${RED}[Scanner]${NC} Details: $scan_output"
        
        # Log result
        echo "$(date -Iseconds)|INFECTED|$file_name|$hash|$file_size|$scan_output" >> "$SCAN_LOG"
        return 1
    fi
}

# Scan directory recursively
scan_directory() {
    local dir="$1"
    
    echo -e "${GREEN}[Scanner]${NC} Scanning directory: $dir"
    
    local file_count=0
    local clean_count=0
    local infected_count=0
    
    while IFS= read -r -d '' file; do
        ((file_count++))
        
        if scan_file "$file"; then
            ((clean_count++))
        else
            ((infected_count++))
        fi
    done < <(find "$dir" -type f -print0)
    
    echo -e "${GREEN}[Scanner]${NC} =================================================="
    echo -e "${GREEN}[Scanner]${NC} Scan Summary:"
    echo -e "${GREEN}[Scanner]${NC}   Total files: $file_count"
    echo -e "${GREEN}[Scanner]${NC}   Clean: $clean_count"
    echo -e "${RED}[Scanner]${NC}   Infected: $infected_count"
}

# Update virus definitions
update_definitions() {
    echo -e "${GREEN}[Scanner]${NC} Updating virus definitions..."
    freshclam
    echo -e "${GREEN}[Scanner]${NC} Update complete"
}

# Main function
main() {
    case "${1:-}" in
        --file)
            init_scanner
            scan_file "${2:-}"
            ;;
        --directory)
            init_scanner
            scan_directory "${2:-}"
            ;;
        --update)
            update_definitions
            ;;
        --help|*)
            cat << EOF
ClamAV Scanner Utility

Usage:
  scanner.sh --file <path>       Scan a single file
  scanner.sh --directory <path>  Scan all files in directory
  scanner.sh --update            Update virus definitions
  scanner.sh --help              Show this help

EOF
            ;;
    esac
}

main "$@"
