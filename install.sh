#!/bin/bash
# Installation script for SafeOpen on macOS
# Sets up the CLI tool and builds the Docker image

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}      ${GREEN}SafeOpen Installation Script${NC}                  ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/usr/local/bin"
LOG_DIR="${HOME}/.safeopen/logs"

# Check prerequisites
echo -e "${GREEN}[1/5]${NC} Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error:${NC} Docker is not installed."
    echo "Please install Docker Desktop for macOS from:"
    echo "https://www.docker.com/products/docker-desktop"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}Error:${NC} Docker daemon is not running."
    echo "Please start Docker Desktop and try again."
    exit 1
fi

echo -e "${GREEN}✓${NC} Docker is installed and running"

# Create directories
echo -e "${GREEN}[2/5]${NC} Creating directories..."
mkdir -p "$LOG_DIR"
mkdir -p /tmp/safeopen
echo -e "${GREEN}✓${NC} Directories created"

# Make scripts executable
echo -e "${GREEN}[3/5]${NC} Setting up scripts..."
chmod +x "$SCRIPT_DIR/safeopen.sh"
chmod +x "$SCRIPT_DIR/container/"*.sh
echo -e "${GREEN}✓${NC} Scripts configured"

# Build Docker image
echo -e "${GREEN}[4/5]${NC} Building Docker image (this may take 5-10 minutes)..."
if docker build -t safeopen:latest "$SCRIPT_DIR"; then
    echo -e "${GREEN}✓${NC} Docker image built successfully"
else
    echo -e "${RED}Error:${NC} Failed to build Docker image"
    exit 1
fi

# Install CLI tool
echo -e "${GREEN}[5/5]${NC} Installing CLI tool..."

if [[ -w "$INSTALL_DIR" ]]; then
    ln -sf "$SCRIPT_DIR/safeopen.sh" "$INSTALL_DIR/safeopen"
    echo -e "${GREEN}✓${NC} Installed to $INSTALL_DIR/safeopen"
else
    echo -e "${YELLOW}Note:${NC} Need sudo permission to install to $INSTALL_DIR"
    sudo ln -sf "$SCRIPT_DIR/safeopen.sh" "$INSTALL_DIR/safeopen"
    echo -e "${GREEN}✓${NC} Installed to $INSTALL_DIR/safeopen"
fi

# Verify installation
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Installation complete!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""
echo "Usage examples:"
echo "  safeopen https://example.com              # Open URL"
echo "  safeopen ~/Downloads/document.pdf         # Open file"
echo "  safeopen --scan suspicious-file.exe       # Scan only"
echo "  safeopen --help                           # Show help"
echo ""
echo "Logs location: $LOG_DIR"
echo ""
echo -e "${GREEN}Happy safe browsing!${NC}"
