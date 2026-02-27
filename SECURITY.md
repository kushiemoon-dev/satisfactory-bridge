# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report security vulnerabilities by emailing the maintainer directly. Include:

1. **Description**: Detailed description of the vulnerability
2. **Impact**: What an attacker could potentially do
3. **Steps to Reproduce**: How to reproduce the issue
4. **Proof of Concept**: If applicable (but please be responsible)
5. **Suggested Fix**: If you have ideas on how to fix it

You should receive a response within 48 hours. If the issue is confirmed, we will:

1. Work on a fix
2. Release a security patch
3. Credit you for the discovery (unless you prefer to remain anonymous)

## Security Best Practices for Deployment

### API Key Management

**Critical**: Never hardcode API keys in your code or commit them to version control.

```bash
# GOOD: Use environment variables
export BRIDGE_API_KEY="$(openssl rand -base64 32)"
./bridge

# BAD: Hardcoded in code
# const apiKey = "my-secret-key"  // DON'T DO THIS
```

### Strong API Keys

Generate cryptographically secure API keys:

```bash
# Generate a strong random API key (32 bytes, base64 encoded)
openssl rand -base64 32

# Or use uuidgen
uuidgen
```

### Network Security

1. **Use HTTPS in Production**
   - Run the bridge behind a reverse proxy (nginx, Caddy, Traefik)
   - Enable TLS/SSL certificates (Let's Encrypt recommended)

   Example nginx configuration:
   ```nginx
   server {
       listen 443 ssl http2;
       server_name bridge.example.com;

       ssl_certificate /path/to/cert.pem;
       ssl_certificate_key /path/to/key.pem;

       location / {
           proxy_pass http://localhost:8080;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header Host $host;
       }
   }
   ```

2. **Firewall Configuration**
   - Only expose the bridge port to trusted networks
   - Use firewall rules to restrict access

   ```bash
   # Example: Allow only from specific IP
   ufw allow from 192.168.1.0/24 to any port 8080
   ```

3. **Rate Limiting**
   - Implement rate limiting at the reverse proxy level
   - Prevent brute-force attacks on the API key

### Access Control

1. **Separate API Keys**
   - Use different API keys for different environments (dev, staging, production)
   - Rotate API keys regularly

2. **Principle of Least Privilege**
   - Only grant access to systems that need it
   - Use network segmentation when possible

### Monitoring and Logging

1. **Enable Logging**
   - Monitor bridge access logs
   - Set up alerts for suspicious activity

2. **Log Rotation**
   - Implement log rotation to prevent disk space issues
   - Retain logs for security auditing

### Secure Deployment Checklist

- [ ] API key is strong and randomly generated
- [ ] API key is stored in environment variable (not hardcoded)
- [ ] Bridge runs behind HTTPS reverse proxy in production
- [ ] Firewall rules restrict access to trusted networks
- [ ] Rate limiting is enabled
- [ ] Logs are monitored
- [ ] System and dependencies are up to date
- [ ] Unnecessary services are disabled
- [ ] File permissions are properly set (`chmod 700 bridge`)

### Container Security (Docker)

If running in Docker:

1. **Use environment variables for secrets**
   ```yaml
   # docker-compose.yml
   services:
     bridge:
       environment:
         - BRIDGE_API_KEY=${BRIDGE_API_KEY}
   ```

2. **Run as non-root user**
   ```dockerfile
   USER nobody
   ```

3. **Limit container capabilities**
   ```yaml
   security_opt:
     - no-new-privileges:true
   cap_drop:
     - ALL
   ```

### Regular Updates

- Keep Go runtime updated
- Monitor for security advisories
- Update dependencies regularly

## Known Security Considerations

### API Key in Logs

Earlier versions logged the full API key on startup. This has been fixed in v1.0.0 - only the last 4 characters are now shown.

If using an older version, avoid logging to public locations.

### HTTP vs HTTPS

The bridge itself does not implement HTTPS. You **must** use a reverse proxy with TLS in production. Running the bridge directly exposed to the internet over HTTP is **insecure**.

### FicsIt-Networks Limitations

The in-game Lua environment has limitations:
- The FicsIt-Networks mod may have its own security considerations
- Network communication happens over game protocols
- Consider the security implications of allowing game control

## Vulnerability Disclosure Timeline

1. **Day 0**: Vulnerability reported
2. **Day 1-2**: Confirmation and assessment
3. **Day 3-14**: Development and testing of fix
4. **Day 14**: Security patch released
5. **Day 14+**: Public disclosure (after users have time to update)

## Security Hall of Fame

Contributors who responsibly disclose security vulnerabilities will be listed here (with permission).

---

**Last Updated**: 2026-02-13
