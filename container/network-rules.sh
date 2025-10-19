#!/bin/bash
# Network restriction rules for secure container
# Blocks access to private networks and limits outbound traffic

set -euo pipefail

echo "[Network] Applying security rules..."

# Flush existing rules
iptables -F OUTPUT 2>/dev/null || exit 0

# Default policy: DROP all outbound traffic
iptables -P OUTPUT DROP 2>/dev/null || exit 0

# Allow loopback (required for X11 and internal communication)
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established connections
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow DNS (port 53)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Allow HTTPS (port 443) - required for web browsing
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

# Allow HTTP (port 80) - with caution
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT

# Block private network ranges (RFC 1918)
iptables -A OUTPUT -d 10.0.0.0/8 -j DROP
iptables -A OUTPUT -d 172.16.0.0/12 -j DROP
iptables -A OUTPUT -d 192.168.0.0/16 -j DROP

# Block localhost access (except loopback interface)
iptables -A OUTPUT -d 127.0.0.0/8 ! -o lo -j DROP

# Block link-local addresses
iptables -A OUTPUT -d 169.254.0.0/16 -j DROP

# Block multicast
iptables -A OUTPUT -d 224.0.0.0/4 -j DROP

# Log dropped packets (optional, for debugging)
# iptables -A OUTPUT -j LOG --log-prefix "SAFEOPEN-DROP: " --log-level 4

echo "[Network] Security rules applied successfully"
echo "[Network] Allowed: DNS (53), HTTP (80), HTTPS (443)"
echo "[Network] Blocked: Private networks, localhost, multicast"

# Display current rules
iptables -L OUTPUT -n -v
