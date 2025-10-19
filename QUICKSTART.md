# SafeOpen Quick Start Guide

Get up and running with SafeOpen in 5 minutes!

## Prerequisites Check

Before starting, ensure you have:

```bash
# Check if Docker is installed
docker --version
# Should show: Docker version 20.x.x or higher

# Check if Docker is running
docker info
# Should show system info without errors
```

If Docker is not installed:
1. Download [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop)
2. Install and launch Docker Desktop
3. Wait for Docker to start (check menu bar icon)

## Installation (5 minutes)

```bash
# 1. Navigate to the SafeOpen directory
cd /path/to/safeopen

# 2. Run the installation script
chmod +x install.sh
./install.sh

# This will:
# - Verify Docker is running
# - Build the secure container image (~5 minutes)
# - Install the CLI tool to /usr/local/bin
# - Create log directories

# 3. Verify installation
safeopen --help
```

## Your First Safe Browse

### Example 1: Open a Suspicious URL

```bash
# Open any URL safely in an isolated container
safeopen https://example.com

# What happens:
# 1. Container spawns in ~5 seconds
# 2. Chromium browser launches
# 3. You browse normally
# 4. When you close browser, container self-destructs
# 5. No trace left on your system
```

### Example 2: Scan and Open a File

```bash
# Download a test file
curl -o ~/Downloads/test.html https://example.com/index.html

# Open it safely (scans first, then opens if clean)
safeopen ~/Downloads/test.html

# What happens:
# 1. File copied to secure location
# 2. ClamAV scans for malware
# 3. SHA256 hash calculated and logged
# 4. If clean, opens in browser
# 5. Container destroyed after closing
# 6. Original file untouched
```

### Example 3: Scan Without Opening

```bash
# Just scan a file to check if it's safe
safeopen --scan ~/Downloads/suspicious.exe

# What happens:
# 1. File scanned with ClamAV
# 2. Results displayed
# 3. Hash logged for audit
# 4. File not opened
```

## Common Commands

```bash
# Open URL
safeopen https://suspicious-site.com

# Open file
safeopen document.pdf

# Scan file only
safeopen --scan attachment.zip

# View recent logs
safeopen --logs

# Clean up old containers
safeopen --cleanup

# Rebuild image (updates virus definitions)
safeopen --rebuild
```

## Understanding the Output

When you run `safeopen https://example.com`, you'll see:

```
╔════════════════════════════════════════════════════════╗
║          SafeOpen - Secure Browser                     ║
╚════════════════════════════════════════════════════════╝

[SafeOpen] Docker version: 24.0.6
[SafeOpen] Checking for Docker image: safeopen:latest
[SafeOpen] Image found. Use --rebuild to force rebuild.
[SafeOpen] Opening URL: https://example.com
[SafeOpen] Container: safeopen_1729332645_12345
[SafeOpen] Initializing virtual display...
[SafeOpen] Browser launched (PID: 123)
[SafeOpen] Browser closed
[SafeOpen] Cleaning up...
[SafeOpen] Cleanup complete. Container will self-destruct.
[SafeOpen] ✓ Session completed successfully
```

## Verifying Security

### Check Container Isolation

```bash
# In one terminal, start a safe browsing session
safeopen https://example.com

# In another terminal, view running containers
docker ps --filter "name=safeopen"

# You'll see the isolated container running
# When you close the browser, it disappears
```

### View Logs

```bash
# View session history
cat ~/.safeopen/logs/access.log

# Example output:
# 2025-10-19T10:30:45|URL|https://example.com|safeopen_1729332645_12345
# 2025-10-19T10:32:15|FILE|document.pdf|abc123...|safeopen_1729332735_12346
```

### Check Malware Detection

```bash
# Download EICAR test file (harmless malware test)
curl -o ~/Downloads/eicar.com https://secure.eicar.org/eicar.com

# Scan it - should be detected
safeopen --scan ~/Downloads/eicar.com

# Expected output:
# [SafeOpen] Scanning file: eicar.com
# [SafeOpen] File SHA256: 275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f
# [SafeOpen Error] ⚠ THREAT DETECTED IN FILE!
# [SafeOpen Error] File has been removed for safety.
```

## Testing Your Installation

Run the test suite:

```bash
chmod +x test.sh
./test.sh

# Should see:
# ╔════════════════════════════════════════════════════════╗
# ║          SafeOpen Test Suite                           ║
# ╚════════════════════════════════════════════════════════╝
#
# Test 1: Docker availability
# ✓ PASS: Docker command found
# ✓ PASS: Docker daemon is running
# ...
# ════════════════════════════════════════════════════════
# Tests Passed: 12
# Tests Failed: 0
# ════════════════════════════════════════════════════════
# All tests passed! ✓
```

## Tips for Daily Use

### 1. Before Opening Suspicious Links

```bash
# Always scan files first if unsure
safeopen --scan suspicious-attachment.pdf

# If clean, then open
safeopen suspicious-attachment.pdf
```

### 2. Keep Updated

```bash
# Update virus definitions monthly
safeopen --rebuild
```

### 3. Review Activity

```bash
# Check what you've opened
safeopen --logs

# Or view full log
less ~/.safeopen/logs/access.log
```

### 4. Clean Up Regularly

```bash
# Remove old stopped containers
safeopen --cleanup
```

## Troubleshooting

### "Docker daemon is not running"

```bash
# Start Docker Desktop from Applications
open -a Docker

# Wait for Docker to be ready
while ! docker info > /dev/null 2>&1; do
    echo "Waiting for Docker..."
    sleep 2
done
echo "Docker is ready!"
```

### "Image not found"

```bash
# Build the image
safeopen --rebuild
```

### "Permission denied"

```bash
# Make sure scripts are executable
chmod +x safeopen.sh install.sh test.sh
chmod +x container/*.sh

# Reinstall
./install.sh
```

### Container won't start

```bash
# Clean everything and rebuild
safeopen --cleanup
docker system prune -a
./install.sh
```

## What's Happening Behind the Scenes?

When you run `safeopen https://example.com`:

1. **Container Spawns** (~5s)
   - Creates isolated Docker container
   - Sets up security restrictions
   - Configures network isolation

2. **Virtual Display** (~2s)
   - Starts Xvfb (virtual X11 server)
   - Browser can render without physical display

3. **Browser Launches** (~2s)
   - Chromium starts with security flags
   - Incognito mode (no persistent data)
   - Loads your URL

4. **You Browse**
   - Interact normally
   - Any malware is contained
   - Network access is restricted

5. **Session Ends**
   - Close browser
   - Container destroys itself
   - Temp files deleted
   - Logs saved for audit

## Next Steps

Now that you're set up:

1. **Read the full README**: `less README.md`
2. **Understand the architecture**: `less ARCHITECTURE.md`
3. **Review security features**: `less SECURITY.md`
4. **Start safe browsing!**

## Need Help?

- **Documentation**: Check README.md for detailed info
- **Issues**: Report at GitHub Issues
- **Questions**: Use GitHub Discussions
- **Security**: Email security@example.com

---

**Happy Safe Browsing! 🔒**

Questions? Run `safeopen --help` or read the full documentation.
