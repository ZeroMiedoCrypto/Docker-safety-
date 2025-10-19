#!/bin/bash
# Uninstall script for SafeOpen

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${RED}SafeOpen Uninstall Script${NC}"
echo ""

read -p "Are you sure you want to uninstall SafeOpen? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

# Remove CLI tool
echo -e "${YELLOW}[1/4]${NC} Removing CLI tool..."
if [[ -f /usr/local/bin/safeopen ]]; then
    sudo rm -f /usr/local/bin/safeopen
    echo -e "${GREEN}✓${NC} CLI tool removed"
else
    echo "CLI tool not found, skipping"
fi

# Remove Docker image
echo -e "${YELLOW}[2/4]${NC} Removing Docker image..."
if docker image inspect safeopen:latest &> /dev/null; then
    docker rmi safeopen:latest
    echo -e "${GREEN}✓${NC} Docker image removed"
else
    echo "Docker image not found, skipping"
fi

# Remove containers
echo -e "${YELLOW}[3/4]${NC} Removing containers..."
containers=$(docker ps -a --filter "name=safeopen_" --format "{{.Names}}" || true)
if [[ -n "$containers" ]]; then
    echo "$containers" | xargs docker rm -f
    echo -e "${GREEN}✓${NC} Containers removed"
else
    echo "No containers found, skipping"
fi

# Ask about user data
echo -e "${YELLOW}[4/4]${NC} User data..."
read -p "Remove logs and user data from ~/.safeopen? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "${HOME}/.safeopen"
    echo -e "${GREEN}✓${NC} User data removed"
else
    echo "User data preserved in ${HOME}/.safeopen"
fi

echo ""
echo -e "${GREEN}Uninstall complete!${NC}"
