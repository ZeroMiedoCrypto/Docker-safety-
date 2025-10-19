# SafeOpen - Secure Disposable Container for Safe Browsing

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)
![Docker](https://img.shields.io/badge/docker-%3E%3D4.30-blue.svg)

A secure, isolated environment for opening potentially unsafe links or files on macOS. The system prevents malware, data exfiltration, and host contamination while preserving usability.

## 🔒 Overview

SafeOpen provides a **disposable Docker container** that runs a hardened Linux environment with an isolated Chromium browser and ClamAV malware scanner. The container has restricted outbound network access and read-only mounts. After the session ends, the container self-destructs to ensure no persistence.

### Key Features

- ✅ **Isolated browsing environment** - Runs in ephemeral Docker container
- ✅ **Malware scanning** - ClamAV scans all files before opening
- ✅ **Network restrictions** - Limited outbound access, blocks private networks
- ✅ **Security hardening** - Non-root user, read-only mounts, dropped capabilities
- ✅ **Auto-cleanup** - Container and temporary files deleted after session
- ✅ **Activity logging** - SHA256 hashes and timestamps for audit trail
- ✅ **Simple CLI** - One command to safely open URLs or files

## 🏗️ Architecture

```mermaid
flowchart TD
    A[User: safeopen <file_or_url>] --> B[Host CLI Wrapper]
    B --> C[Docker Daemon]
    C --> D[Ephemeral Container]
    D --> E[Chromium Browser]
    D --> F[ClamAV Scanner]
    D --> G[/var/safe_logs]
    E --> H[Restricted Network]
    D --> I[Auto-cleanup]
```

## 📋 Requirements

- **macOS** (tested on macOS 12+)
- **Docker Desktop** ≥ 4.30
- **Bash** (built-in on macOS)
- **Disk Space**: ~2 GB for Docker image

## 🚀 Quick Start

### Installation

```bash
# Clone or download this repository
git clone https://github.com/yourusername/safeopen.git
cd safeopen

# Run installation script
chmod +x install.sh
./install.sh
```

The installation will:
1. Check Docker availability
2. Build the secure container image (~5-10 minutes)
3. Install the `safeopen` CLI tool to `/usr/local/bin`
4. Create log directories

### Basic Usage

```bash
# Open a URL
safeopen https://suspicious-website.com

# Open and scan a file
safeopen ~/Downloads/attachment.pdf

# Scan a file without opening
safeopen --scan ~/Downloads/suspicious.exe

# View help
safeopen --help
```

## 📖 Detailed Usage

### Opening URLs

```bash
# Direct URL
safeopen https://example.com

# Explicit URL flag
safeopen --url https://example.com
```

The browser will launch in an isolated container with:
- Incognito mode enabled
- No extensions or plugins
- Restricted network access
- Automatic cleanup on close

### Opening Files

```bash
# Auto-detect file type
safeopen document.pdf

# Explicit file flag
safeopen --file ~/Downloads/attachment.html
```

Files are:
1. Copied to temporary location
2. Scanned with ClamAV for malware
3. Opened in secure browser if clean
4. Deleted from temporary storage after session

### Scanning Only

```bash
# Scan without opening
safeopen --scan suspicious-file.exe
```

Perfect for checking files before deciding to open them.

### Maintenance Commands

```bash
# Rebuild Docker image (after updates)
safeopen --rebuild

# Clean up old containers
safeopen --cleanup

# View session logs
safeopen --logs
```

## 🔐 Security Features

### Container Security

- **Non-root execution**: Container runs as `safeuser` (UID 1000)
- **Read-only filesystem**: Host mounts are read-only except logs
- **Dropped capabilities**: All Linux capabilities dropped except essential ones
- **No new privileges**: Prevents privilege escalation
- **Isolated network**: Custom network with restricted outbound access
- **Temporary filesystems**: `/tmp` and home directory are tmpfs (memory-only)

### Network Restrictions

The container enforces strict network rules:

- ✅ **Allowed**: HTTPS (443), HTTP (80), DNS (53)
- ❌ **Blocked**: Private networks (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
- ❌ **Blocked**: Localhost access (127.0.0.0/8)
- ❌ **Blocked**: Multicast and link-local addresses

### File Scanning

All files are scanned with ClamAV before opening:
- SHA256 hash calculated and logged
- Virus signature detection
- Infected files automatically removed
- Scan results logged for audit

### Browser Security

Chromium runs with hardened flags:
- `--no-sandbox` (safe within container isolation)
- `--incognito` (no persistent storage)
- `--disable-extensions`
- `--disable-sync`
- `--disable-background-networking`
- And many more security-focused flags

## 📊 Logging

### Log Locations

```
~/.safeopen/logs/
├── access.log      # Session history (URLs/files opened)
└── session.log     # Detailed scan results
```

### Log Format

**Access Log:**
```
2025-10-19T10:30:45|URL|https://example.com|safeopen_1729332645_12345
2025-10-19T10:32:15|FILE|document.pdf|abc123def...|safeopen_1729332735_12346
```

**Session Log:**
```
2025-10-19T10:32:15|SCAN_CLEAN|document.pdf|abc123def...|2048576
2025-10-19T10:35:20|SCAN_INFECTED|malware.exe|def456abc...|1024000|Win.Trojan.Agent
```

## 🧪 Testing

Run the test suite to verify installation:

```bash
chmod +x test.sh
./test.sh
```

Tests include:
- Docker availability
- Image build verification
- CLI tool installation
- Script permissions
- Basic file scanning

## 🔧 Configuration

### Environment Variables

You can customize behavior with environment variables:

```bash
# Enable VNC for remote viewing (debugging)
SAFEOPEN_ENABLE_VNC=true safeopen https://example.com

# Custom log directory
SAFEOPEN_LOG_DIR=/custom/path safeopen --url https://example.com
```

### Docker Image Customization

Edit `Dockerfile` to customize the container:
- Change base image (currently Ubuntu 22.04)
- Add additional tools (PDF viewers, office viewers)
- Modify ClamAV configuration
- Adjust security policies

After changes, rebuild:
```bash
safeopen --rebuild
```

## 📈 Performance Metrics

| Metric | Target | Typical |
|--------|--------|---------|
| Container startup | < 10s | 5-8s |
| File scan (1MB) | < 2s | 0.5-1s |
| Memory usage | < 512MB | 300-400MB |
| Disk usage | < 2GB | 1.5GB |

## 🛠️ Troubleshooting

### Docker not running

```bash
# Check Docker status
docker info

# Start Docker Desktop
open -a Docker
```

### Container fails to start

```bash
# Check Docker logs
docker logs <container-name>

# Rebuild image
safeopen --rebuild

# Clean old containers
safeopen --cleanup
```

### Permission denied

```bash
# Ensure scripts are executable
chmod +x safeopen.sh install.sh
chmod +x container/*.sh

# Reinstall CLI tool
./install.sh
```

### ClamAV database outdated

The container updates virus definitions during build. To update:

```bash
safeopen --rebuild
```

## 🔄 Uninstallation

```bash
chmod +x uninstall.sh
./uninstall.sh
```

This will:
1. Remove CLI tool from `/usr/local/bin`
2. Delete Docker image
3. Remove all containers
4. Optionally delete user data and logs

## 🚧 Future Enhancements

- [ ] GUI launcher app with drag-and-drop
- [ ] VirusTotal API integration for multi-engine scanning
- [ ] Persistent "safe workspace" mode for extended analysis
- [ ] Support for additional viewers (LibreOffice, etc.)
- [ ] Windows and Linux support
- [ ] Network traffic inspection with proxy
- [ ] Automatic updates for virus definitions

## 📝 Project Structure

```
safeopen/
├── Dockerfile              # Container image definition
├── safeopen.sh            # Main CLI wrapper script
├── install.sh             # Installation script
├── uninstall.sh           # Uninstallation script
├── test.sh                # Test suite
├── container/
│   ├── entrypoint.sh      # Container entry point
│   ├── network-rules.sh   # iptables configuration
│   ├── scanner.sh         # ClamAV scanning utility
│   ├── cleanup.sh         # Cleanup script
│   └── apparmor-profile   # AppArmor security profile
├── logs/                  # (created at runtime)
└── README.md
```

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## ⚠️ Disclaimer

SafeOpen provides significant security improvements for opening untrusted content, but no system is 100% secure. Use good judgment:

- Keep Docker and system updated
- Review logs regularly
- Don't disable security features
- Report suspicious behavior

**For highly sensitive operations, consider using a dedicated isolated machine.**

## 🙏 Acknowledgments

- **ClamAV** - Open-source antivirus engine
- **Chromium** - Open-source browser project
- **Docker** - Container platform
- Ubuntu community for secure base images

## 📞 Support

- Issues: [GitHub Issues](https://github.com/yourusername/safeopen/issues)
- Discussions: [GitHub Discussions](https://github.com/yourusername/safeopen/discussions)
- Security issues: security@example.com

---

**Happy Safe Browsing! 🔒**
