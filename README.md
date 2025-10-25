# safeopen: Disposable Sandbox for Risky Links and Files

`safeopen` provides a hardened disposable environment for inspecting untrusted URLs or documents from macOS. The tool orchestrates an Ubuntu-based Docker container that runs Chromium within an isolated VNC session and scans inbound files with ClamAV before they are rendered. Each session is ephemeral: temporary copies of the inspected files are destroyed, and the container is deleted on exit.

## Features

- **Disposable container runtime** – automatically builds and launches a one-off sandbox using Docker Desktop.
- **Chromium over VNC** – runs a full Chromium browser behind a TigerVNC server so the host never renders untrusted content directly.
- **Pre-scan with ClamAV** – files are hashed, scanned, and only opened if clean.
- **Restrictive networking** – outbound traffic is limited to HTTPS and DNS, and access to RFC1918/private address space is blocked.
- **Minimal logging** – timestamped activity logs stay local at `~/.safeopen/logs/`.
- **Automatic cleanup** – temporary mounts are removed and the container self-destructs when Chromium exits.

## Prerequisites

- macOS with [Docker Desktop 4.30+](https://www.docker.com/products/docker-desktop/).
- At least 4 GB of free RAM and 2 CPU cores assigned to Docker Desktop.
- (Optional) An AppArmor-compatible Linux host if you plan to enforce the included profile when running on Linux.

## Installation

```bash
# install the CLI wrapper
make install

# verify the CLI is reachable
safeopen --help
```

The Makefile installs the launcher to `/usr/local/bin/safeopen` by default. Use `DESTDIR`/`PREFIX` if you need a different location.

## Usage

```bash
safeopen https://example.com
safeopen ~/Downloads/suspicious.pdf
```

The script will:

1. Build the Docker image on first run.
2. Copy the provided file (if any) into an isolated temporary directory and record its SHA256 hash.
3. Launch a sandboxed container with Chromium available over VNC on `localhost:5901` (a random password is printed to the terminal).
4. Update virus definitions, scan inbound files with ClamAV, and open the target in Chromium.
5. Tear down the container and temporary directories when Chromium exits.

### Accessing the Browser

Use a VNC client such as **TigerVNC Viewer** or **Screens** to connect to `localhost:5901` using the password displayed by `safeopen`. Close Chromium (or the VNC window) when finished to terminate the session. Each invocation generates a new random password.

## Security Hardening

- Containers start as read-only with tmpfs mounts for `/tmp`, `/run`, `/home/safeuser`, `/var/lib/clamav`, and `/var/safe_logs` to prevent persistence.
- All Linux capabilities are dropped and `no-new-privileges` is enforced.
- Custom iptables rules allow only DNS (53/UDP+TCP) and HTTPS (443/TCP) egress, while explicitly blocking private address ranges.
- The ClamAV database is refreshed on launch over HTTPS before scans run.
- Chromium runs as the non-root `safeuser` account inside the container.

For additional defense-in-depth on Linux hosts, load the bundled AppArmor profile. The CLI automatically enables it when Docker reports AppArmor support:

```bash
sudo apparmor_parser -r apparmor/safeopen
safeopen https://example.com
```

> **Note for macOS:** Docker Desktop does not yet expose custom AppArmor profiles. The profile is supplied for Linux users and documentation purposes.

### Advanced Options

- Set `SAFEOPEN_DISABLE_HARDENING=1` to skip automatic AppArmor and user-namespace flags if you need to troubleshoot Docker runtime compatibility.

## Logs

Session metadata is written to `~/.safeopen/logs/<date>.log` in the format:

```
2024-05-31T12:34:56+00:00 SUCCESS URL https://example.com
```

For files, the SHA256 hash is logged prior to the session result.

## Troubleshooting

- **Chromium fails to launch** – ensure Docker Desktop has access to at least 2 CPUs and 4 GB RAM.
- **Cannot connect to VNC** – check that port `5901` is not already in use on the host. The CLI always maps container port 5901 to the host.
- **Slow ClamAV updates** – the first run downloads the full virus definition database and may take a few minutes.

## Future Enhancements

- Optional VirusTotal enrichment for file scans.
- Native macOS application wrapper for drag-and-drop usage.
- Additional file viewers for PDFs and Office documents inside the container.

## License

This project is provided under the MIT License. See `LICENSE` for details.
