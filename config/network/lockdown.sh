#!/usr/bin/env bash
set -euo pipefail

if ! command -v iptables >/dev/null 2>&1; then
    exit 0
fi

# Flush existing OUTPUT rules to avoid duplicates
iptables -F OUTPUT || true
iptables -P OUTPUT DROP || true
iptables -A OUTPUT -o lo -j ACCEPT || true
iptables -A OUTPUT -d 127.0.0.0/8 -j ACCEPT || true

# Allow established connections for localhost display forwarding if needed
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT || true
