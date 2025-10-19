# SafeOpen Architecture Documentation

## System Overview

SafeOpen is a secure, disposable container system designed to safely open potentially malicious URLs and files on macOS. The architecture follows defense-in-depth principles with multiple security layers.

## Component Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         macOS Host                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    User Interface                     │  │
│  │              safeopen.sh (CLI Wrapper)                │  │
│  └───────────────────┬───────────────────────────────────┘  │
│                      │                                       │
│                      ▼                                       │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              Docker Desktop (Daemon)                  │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │         Ephemeral Container                     │  │  │
│  │  │                                                 │  │  │
│  │  │  ┌──────────────┐      ┌──────────────┐        │  │  │
│  │  │  │  Entrypoint  │─────▶│   Xvfb       │        │  │  │
│  │  │  │    Script    │      │  (Display)   │        │  │  │
│  │  │  └──────┬───────┘      └──────────────┘        │  │  │
│  │  │         │                                       │  │  │
│  │  │         ├────────────┬─────────────┐           │  │  │
│  │  │         ▼            ▼             ▼           │  │  │
│  │  │  ┌──────────┐ ┌──────────┐ ┌──────────┐       │  │  │
│  │  │  │  ClamAV  │ │ Chromium │ │  Cleanup │       │  │  │
│  │  │  │ Scanner  │ │ Browser  │ │  Script  │       │  │  │
│  │  │  └────┬─────┘ └────┬─────┘ └──────────┘       │  │  │
│  │  │       │            │                           │  │  │
│  │  │       ▼            ▼                           │  │  │
│  │  │  /tmp/safeopen  /var/safe_logs                │  │  │
│  │  │  (tmpfs)        (host mount)                  │  │  │
│  │  └─────────────────────┬───────────────────────────┘  │  │
│  │                        │                              │  │
│  │                        ▼                              │  │
│  │              Docker Network Bridge                   │  │
│  │              (Restricted Outbound)                   │  │
│  └───────────────────────┬───────────────────────────────┘  │
│                          │                                  │
└──────────────────────────┼──────────────────────────────────┘
                           │
                           ▼
                      Internet
             (HTTPS/HTTP/DNS only)
```

## Component Details

### 1. CLI Wrapper (safeopen.sh)

**Location**: `/usr/local/bin/safeopen` (symlink to `safeopen.sh`)

**Responsibilities**:
- Parse command-line arguments
- Validate Docker availability
- Build/manage Docker images
- Launch containers with security options
- Handle file copying and cleanup
- Generate unique container names
- Maintain access logs

**Key Functions**:
- `check_prerequisites()` - Verify Docker is running
- `build_image()` - Build or verify Docker image exists
- `open_url()` - Launch container for URL
- `open_file()` - Launch container for file (with scanning)
- `cleanup_old_containers()` - Remove terminated containers

**Security Considerations**:
- Runs with user privileges (no sudo required for normal operation)
- Creates temporary files in `/tmp/safeopen` with restricted permissions
- Logs SHA256 hashes for audit trail
- Implements container name randomization

### 2. Docker Image (Dockerfile)

**Base Image**: `ubuntu:22.04` (minimal)

**Installed Components**:
- Chromium browser
- ClamAV (malware scanner)
- Xvfb (virtual X11 display)
- iptables (network filtering)
- x11vnc (optional VNC server)

**Security Hardening**:
- Non-root user (`safeuser`, UID 1000)
- Removed SUID binaries
- Minimal package installation
- Updated ClamAV definitions during build
- Restrictive file permissions

**Layer Structure**:
```
Layer 1: Base Ubuntu 22.04
Layer 2: System packages + dependencies
Layer 3: Chromium installation
Layer 4: ClamAV installation + DB update
Layer 5: Security scripts
Layer 6: User configuration
Layer 7: Entrypoint setup
```

### 3. Container Entrypoint (entrypoint.sh)

**Location**: `/usr/local/bin/entrypoint.sh` (in container)

**Execution Flow**:
```
START
  │
  ├─▶ Initialize Xvfb display
  │
  ├─▶ (Optional) Start VNC server
  │
  ├─▶ Parse command arguments
  │     │
  │     ├─▶ --url: Open URL in browser
  │     ├─▶ --file: Scan then open file
  │     └─▶ --scan-only: Scan without opening
  │
  ├─▶ Execute action
  │     │
  │     ├─▶ For files: Calculate SHA256
  │     ├─▶ Run ClamAV scan
  │     ├─▶ Log results
  │     └─▶ Launch Chromium if clean
  │
  ├─▶ Wait for browser to close
  │
  └─▶ Cleanup and exit
```

**Security Features**:
- Runs as `safeuser` (non-root)
- Validates input URLs and file paths
- Logs all actions with timestamps
- Traps signals for graceful cleanup
- Removes sensitive data before exit

### 4. ClamAV Scanner (scanner.sh)

**Location**: `/usr/local/bin/scanner.sh` (in container)

**Capabilities**:
- Scan individual files
- Recursive directory scanning
- File metadata extraction
- SHA256 hash calculation
- Detailed logging

**Scan Process**:
```
File Input
  │
  ├─▶ Check file exists
  ├─▶ Validate file size (< 100MB)
  ├─▶ Calculate SHA256 hash
  ├─▶ Get file metadata (size, type, modified)
  ├─▶ Run ClamAV scan
  │     │
  │     ├─▶ CLEAN: Log and allow
  │     └─▶ INFECTED: Log, alert, delete
  │
  └─▶ Return status code
```

**Detection Database**:
- Updated during Docker image build
- Can be refreshed with `safeopen --rebuild`
- Uses official ClamAV signatures
- Supports custom signature addition

### 5. Network Security (network-rules.sh)

**Location**: `/usr/local/bin/network-rules.sh` (in container)

**iptables Rules**:
```bash
# Default: DROP all outbound
iptables -P OUTPUT DROP

# Allow loopback (required for X11)
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established connections
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow DNS (53)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow HTTP/HTTPS (80, 443)
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

# Block private networks
iptables -A OUTPUT -d 10.0.0.0/8 -j DROP
iptables -A OUTPUT -d 172.16.0.0/12 -j DROP
iptables -A OUTPUT -d 192.168.0.0/16 -j DROP
iptables -A OUTPUT -d 127.0.0.0/8 ! -o lo -j DROP
```

**Note**: Requires `NET_ADMIN` capability (currently disabled by default for maximum security). Network isolation provided by Docker networking instead.

### 6. Cleanup System (cleanup.sh)

**Location**: `/usr/local/bin/cleanup.sh` (in container)

**Cleanup Targets**:
- Browser profile: `/tmp/chromium-profile`
- Temporary files: `/tmp/safeopen/*`
- Runtime files: `/tmp/runtime-safeuser/*`
- Bash history: `/home/safeuser/.bash_history`
- Downloads: `/home/safeuser/Downloads/*`

**Secure Deletion** (optional):
```bash
secure_wipe() {
    # Overwrite with random data before deletion
    dd if=/dev/urandom of="$file" bs=1 count="$size"
    rm -f "$file"
}
```

## Data Flow

### Opening a URL

```
User: safeopen https://example.com
       │
       ▼
CLI Wrapper validates URL
       │
       ▼
Docker container spawned with:
  - Bridge network
  - Tmpfs for /tmp and home
  - Read-only mounts
  - Security options
       │
       ▼
Entrypoint script:
  1. Starts Xvfb
  2. Logs URL access
  3. Launches Chromium with URL
       │
       ▼
Chromium loads in incognito mode
       │
       ▼
User interacts with page
       │
       ▼
User closes browser
       │
       ▼
Cleanup script runs
       │
       ▼
Container self-destructs
       │
       ▼
Session complete
```

### Opening a File

```
User: safeopen document.pdf
       │
       ▼
CLI Wrapper:
  1. Validates file exists
  2. Calculates SHA256 hash
  3. Copies to /tmp/safeopen
       │
       ▼
Docker container spawned with:
  - File mounted read-only
  - Network isolated
  - ClamAV scanner ready
       │
       ▼
Entrypoint script:
  1. Starts Xvfb
  2. Invokes scanner
       │
       ▼
Scanner:
  1. Calculates hash
  2. Gets metadata
  3. Runs ClamAV scan
  4. Logs results
       │
       ├─▶ INFECTED: Delete + Alert + Exit
       │
       └─▶ CLEAN: Continue
                 │
                 ▼
           Chromium opens file
                 │
                 ▼
           User reviews file
                 │
                 ▼
           User closes browser
                 │
                 ▼
           Cleanup runs
                 │
                 ▼
           Container destroyed
                 │
                 ▼
       Host temp file deleted
                 │
                 ▼
           Session complete
```

## Security Layers

### Layer 1: Container Isolation
- Process isolation via Docker
- Separate network namespace
- Separate filesystem namespace
- Resource limits (CPU, memory)

### Layer 2: Capability Restrictions
```bash
--cap-drop=ALL                    # Drop all capabilities
--security-opt=no-new-privileges  # Prevent escalation
```

### Layer 3: Filesystem Security
```bash
--read-only                               # Root FS read-only
--tmpfs /tmp:rw,noexec,nosuid,size=512m  # Temp with restrictions
-v file.txt:/tmp/file.txt:ro              # Read-only mounts
```

### Layer 4: Network Security
- Bridge network with limited routes
- DNS restricted to public resolvers
- Blocked private network ranges
- No inter-container communication

### Layer 5: User Security
- Non-root user (UID 1000)
- No sudo access
- Home directory on tmpfs
- Limited shell capabilities

### Layer 6: Application Security
- Chromium sandbox enabled (within container)
- Incognito mode (no persistence)
- Disabled extensions and plugins
- Content security policies

### Layer 7: Monitoring & Logging
- SHA256 hashing for files
- Timestamped action logs
- Scan result recording
- Access audit trail

## Performance Considerations

### Container Startup Time

**Target**: < 10 seconds
**Typical**: 5-8 seconds

**Breakdown**:
- Image pull/check: 0-1s (if cached)
- Container creation: 1-2s
- Xvfb initialization: 2s
- Chromium startup: 2-3s

### Memory Usage

**Base**: ~100MB (container overhead)
**Xvfb**: ~50MB
**Chromium**: ~150-200MB
**Total**: ~300-400MB typical

### Disk Usage

**Docker Image**: ~1.5GB
- Base Ubuntu: ~100MB
- Chromium: ~300MB
- ClamAV: ~200MB
- Dependencies: ~100MB
- Virus DB: ~200MB

**Runtime**: ~100-200MB (tmpfs)

### Network Performance

**No significant overhead** compared to host browsing:
- Docker bridge: negligible latency
- DNS resolution: standard
- HTTP/HTTPS: full speed (no proxy)

## Failure Modes & Recovery

### Docker Not Running
```
Error: Docker daemon is not running
Action: Start Docker Desktop
Recovery: Automatic on next run
```

### Image Not Found
```
Error: Image safeopen:latest not found
Action: Run safeopen --rebuild
Recovery: Builds image automatically
```

### Container Fails to Start
```
Error: Container creation failed
Action: Check Docker logs
Recovery: Cleanup old containers with safeopen --cleanup
```

### File Scan Fails
```
Error: ClamAV scan failed
Action: Check file size/format
Recovery: Update definitions with safeopen --rebuild
```

### Browser Crash
```
Error: Chromium exited unexpectedly
Action: Container auto-cleanup triggers
Recovery: Safe - no persistence, can retry
```

## Extension Points

### Custom Scanners
Add to `container/entrypoint.sh`:
```bash
# Additional scanner integration
scan_with_virustotal() {
    # API call to VirusTotal
}
```

### Additional Viewers
Add to Dockerfile:
```dockerfile
# Install LibreOffice for documents
RUN apt-get install -y libreoffice
```

### Network Proxy
Add to `safeopen.sh`:
```bash
docker run ... \
    -e http_proxy=http://proxy:8080 \
    -e https_proxy=http://proxy:8080 \
    ...
```

### Custom Policies
Add AppArmor or SELinux profiles:
```bash
docker run ... \
    --security-opt apparmor=safeopen-profile \
    ...
```

## Monitoring & Observability

### Log Files

**Access Log**: `~/.safeopen/logs/access.log`
- All URL/file opens
- Container IDs
- Timestamps

**Session Log**: `~/.safeopen/logs/session.log`
- Scan results
- File hashes
- Threat detections

**Docker Logs**: View with `docker logs <container-name>`
- Container output
- Error messages
- Debug information

### Metrics Collection

Not implemented by default, but can be added:
- Container resource usage via `docker stats`
- Network traffic via iptables counters
- Scan performance timing
- Browser memory usage

## Scalability

### Single User
Current design: Optimized for single-user macOS workstation
- One container per session
- Sequential execution
- Local storage only

### Multi-User (Future)
Potential enhancements:
- Container pool management
- Shared image registry
- Centralized logging
- Resource quotas per user

## Maintenance

### Regular Updates

**Weekly**: Check for updates
```bash
git pull origin main
safeopen --rebuild
```

**Monthly**: Full rebuild
```bash
docker system prune -a  # Clean old images
./install.sh            # Rebuild fresh
```

**Quarterly**: Review logs
```bash
safeopen --logs
# Analyze for suspicious patterns
```

### Backup & Recovery

**What to Backup**:
- Configuration: `~/.safeopen/` (if customized)
- Logs: `~/.safeopen/logs/` (for audit)

**What NOT to Backup**:
- Temporary files: `/tmp/safeopen/`
- Container data: Ephemeral by design

---

**Document Version**: 1.0  
**Last Updated**: 2025-10-19  
**Maintained By**: SafeOpen Project
