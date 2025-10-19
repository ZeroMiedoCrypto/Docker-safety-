# Security Policy

## Supported Versions

SafeOpen is currently in active development. Security updates are provided for the latest version only.

| Version | Supported          |
| ------- | ------------------ |
| latest  | :white_check_mark: |

## Security Features

SafeOpen implements multiple layers of security:

### Container Isolation
- Non-root user execution (UID 1000)
- Read-only filesystem except for logs
- Dropped Linux capabilities
- `no-new-privileges` security option
- Temporary filesystems (tmpfs) for /tmp and home

### Network Security
- Restricted outbound access (HTTPS, HTTP, DNS only)
- Blocked private network ranges (RFC 1918)
- Blocked localhost and link-local addresses
- No inter-container communication

### File Security
- ClamAV malware scanning before opening
- SHA256 hash calculation and logging
- Automatic removal of infected files
- Temporary file cleanup after session

### Browser Security
- Chromium with security-hardened flags
- Incognito mode (no persistent storage)
- Disabled extensions and plugins
- Disabled background networking
- No sync or telemetry

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability in SafeOpen, please follow responsible disclosure:

### Do:
1. **Email** security concerns to: security@example.com (or create a private GitHub Security Advisory)
2. **Provide** detailed information:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if available)
3. **Wait** for our response before public disclosure
4. **Give us** reasonable time to address the issue (typically 90 days)

### Don't:
- Don't publicly disclose the vulnerability before a fix is available
- Don't exploit the vulnerability beyond what's necessary for proof-of-concept
- Don't access or modify data that doesn't belong to you

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Development**: Depends on severity (critical: 7-14 days, high: 14-30 days)
- **Public Disclosure**: After fix is released and users have time to update

## Security Best Practices for Users

### Keep Updated
- Update Docker Desktop regularly
- Rebuild SafeOpen image monthly: `safeopen --rebuild`
- Keep macOS updated with latest security patches

### Monitor Activity
- Review logs regularly: `safeopen --logs`
- Check `~/.safeopen/logs/` for suspicious activity
- Monitor Docker container usage

### Use Safely
- Don't disable security features
- Don't modify Dockerfile without understanding implications
- Don't run as root user
- Don't share log files containing sensitive URLs

### Network Safety
- Use SafeOpen on trusted networks
- Consider additional proxy/firewall for high-risk browsing
- Don't use for accessing sensitive personal accounts

### File Safety
- Scan before opening: `safeopen --scan file.exe`
- Don't open extremely large files (>100MB)
- Don't trust clean scan results as 100% guarantee

## Known Limitations

SafeOpen provides significant security improvements but has limitations:

### Technical Limitations
- **Container escape**: While rare, Docker container escapes are possible
- **Zero-day malware**: ClamAV may not detect brand-new malware
- **Network inspection**: Limited deep packet inspection
- **Social engineering**: Cannot protect against phishing if user submits data

### Scope Limitations
- Designed for casual browsing of suspicious links
- Not a replacement for dedicated malware analysis VM
- Not suitable for handling classified or highly sensitive material
- Not designed for long-term safe workspace usage

## Security Audit History

| Date | Type | Auditor | Findings | Status |
|------|------|---------|----------|--------|
| TBD  | External | TBD | TBD | Pending |

## Security-Related Configuration

### Dockerfile Security Options
```dockerfile
USER safeuser                           # Non-root user
--security-opt=no-new-privileges:true  # Prevent privilege escalation
--cap-drop=ALL                         # Drop all capabilities
--read-only                            # Read-only root filesystem
--tmpfs /tmp:rw,noexec,nosuid          # Temporary filesystem restrictions
```

### Network Security Options
```bash
--network bridge                        # Isolated network
--dns 8.8.8.8                          # Specific DNS servers
# iptables rules block private networks
```

### AppArmor Profile
Optional AppArmor profile provided in `container/apparmor-profile` for additional MAC (Mandatory Access Control).

## Compliance

SafeOpen is designed with security best practices but is not certified for:
- HIPAA compliance
- PCI DSS compliance
- Government classified systems
- Enterprise security standards

For compliance requirements, consult your security team before deployment.

## Security Resources

- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [ClamAV Documentation](https://docs.clamav.net/)
- [OWASP Container Security](https://owasp.org/www-project-docker-security/)
- [Chromium Security Architecture](https://www.chromium.org/Home/chromium-security/)

## Contact

- Security Issues: security@example.com
- General Issues: [GitHub Issues](https://github.com/yourusername/safeopen/issues)
- Discussions: [GitHub Discussions](https://github.com/yourusername/safeopen/discussions)

---

Last Updated: 2025-10-19
