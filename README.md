# Docker-safety-

A hardened Chromium sandbox that opens files and URLs inside an isolated Docker container.

## Features

- Ubuntu 22.04 base image with a dedicated non-root user.
- Chromium delivered from Canonical's Chromium builds PPA.
- Mandatory ClamAV scanning prior to launching a session.
- AppArmor profile and container hardening (read-only root, dropped capabilities, user namespace remapping).
- TigerVNC/Xvfb display server inside the container for isolated browsing sessions.
- Automatic logging of access attempts to `~/.safeopen/logs/`.

## Requirements

- Docker 20.10 or newer with user namespaces enabled (`--userns=keep-id`).
- Local installation of ClamAV (`clamscan`) and `sudo` permissions to load AppArmor profiles.
- AppArmor enabled on the host kernel.

## Building the image

```bash
./safeopen.sh --help
```

The script builds (or rebuilds) the `safeopen:latest` image automatically when invoked.

## Usage

```bash
# Open a URL inside the sandboxed Chromium instance
./safeopen.sh https://example.com

# Open a local file after scanning it with ClamAV
./safeopen.sh ~/Downloads/attachment.pdf
```

### What the script does

1. Loads the bundled AppArmor profile (`config/apparmor/safeopen-chromium`).
2. Builds the Docker image if necessary.
3. Runs ClamAV scans on supplied files and records the result.
4. Starts the container with:
   - read-only root filesystem and dedicated tmpfs mounts;
   - networking disabled (with in-container iptables fallback if networking is ever enabled);
   - the `safeopen-chromium` AppArmor profile applied;
   - non-root execution via user namespace remapping.
5. Launches Chromium under TigerVNC (or Xvfb fallback) so the browser runs on an isolated display.
6. Cleans up containers and temporary files after Chromium exits.

Logs are written as timestamped entries to `~/.safeopen/logs/`. Each line includes the ISO timestamp, target, file hash (when applicable), and scan result.

## Configuration

- `config/apparmor/safeopen-chromium`: AppArmor profile applied to the container.
- `config/network/lockdown.sh`: iptables helper invoked by the container entrypoint to block unexpected egress traffic.

You can adjust these files to fit your environment before rebuilding the image.
