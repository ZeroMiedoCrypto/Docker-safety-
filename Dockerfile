# Secure Disposable Container for Safe Browsing
# Base: Ubuntu 22.04 LTS (minimal)
FROM ubuntu:22.04

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Create non-root user for running browser
RUN useradd -m -s /bin/bash -u 1000 safeuser && \
    mkdir -p /home/safeuser/.config /var/safe_logs /tmp/safeopen && \
    chown -R safeuser:safeuser /home/safeuser /var/safe_logs

# Install essential packages, Chromium, ClamAV, and security tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium-browser \
    clamav \
    clamav-daemon \
    clamav-freshclam \
    iptables \
    iproute2 \
    ca-certificates \
    xvfb \
    x11vnc \
    dbus-x11 \
    procps \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Update ClamAV virus definitions
RUN freshclam --quiet || true

# Copy security configuration files
COPY container/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY container/network-rules.sh /usr/local/bin/network-rules.sh
COPY container/scanner.sh /usr/local/bin/scanner.sh
COPY container/cleanup.sh /usr/local/bin/cleanup.sh

# Make scripts executable
RUN chmod +x /usr/local/bin/*.sh

# Set up AppArmor profile (if available)
COPY container/apparmor-profile /etc/apparmor.d/safeopen-profile || true

# Configure chromium to run in sandbox mode with security flags
RUN mkdir -p /etc/chromium/policies/managed && \
    echo '{"CommandLineFlagSecurityWarningsEnabled": false}' > /etc/chromium/policies/managed/policy.json

# Security hardening: Remove unnecessary SUID binaries
RUN find / -perm -4000 -type f 2>/dev/null | xargs chmod -s 2>/dev/null || true

# Set restrictive permissions
RUN chmod 755 /home/safeuser && \
    chmod 700 /var/safe_logs

# Environment variables
ENV DISPLAY=:99
ENV HOME=/home/safeuser
ENV XDG_RUNTIME_DIR=/tmp/runtime-safeuser

# Create runtime directory
RUN mkdir -p /tmp/runtime-safeuser && \
    chown safeuser:safeuser /tmp/runtime-safeuser && \
    chmod 700 /tmp/runtime-safeuser

# Expose VNC port (optional, for debugging)
EXPOSE 5900

# Switch to non-root user
USER safeuser

# Entrypoint script handles all initialization
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Default command (can be overridden)
CMD ["--help"]
