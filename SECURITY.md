# Security

This is built with security in mind from the start.

## What's Actually Secure Here

**Containers run as your user** - not as root. This is a big deal because if something goes wrong in a container, the attacker only gets the permissions of a regular user. Much better than having root compromised.

**User namespaces isolate UID/GID** - means no conflicts between containers, and they can't escape to your actual files.

**We drop unnecessary Linux capabilities** - containers only get the minimal permissions they actually need.

**Backend is internal only** - database and servers don't talk to the internet. Only the web UI is exposed.

**Read-only filesystems** where we can - means containers can't modify their own code.

**Resource limits are set** - so one container going crazy won't take down the whole system.

**Health checks run automatically** - we know when something dies before you do.

### Images

**We scan for vulnerabilities** before pushing - smaller base images mean smaller attack surface. Alpine keeps things minimal. Always updating to get security patches.

No build tools or compilers left in the final images either.

## Reporting Security Issues

**Don't open public GitHub issues for security bugs.** Email the maintainers instead with details:

- What the vulnerability is
- Where it shows up (which container/file)
- Your OS and setup
- How to reproduce it if possible
- Any suggested fix you have

Allow about 90 days before public disclosure for major issues.

## Staying Secure

Keep your setup updated. Run Trivy to scan images before deploying:

```bash
trivy image postgres:16-alpine
trivy image zabbix/zabbix-server-pgsql:latest
```

Use strong passwords for the database. Keep your podman and docker-compose updated. And actually look at the logs sometimes - they tell you when things are broken.

For contributors: don't commit passwords, use git-secrets if you can, and review your own changes before pushing.

## Production Checklist

Before going live:

- Scan all images with Trivy
- Use strong, random passwords - not defaults
- Firewall configured to only open 80/443
- Backups are actually automated
- Monitoring is running and alerting works
- SELinux or AppArmor is on
- Logs go somewhere safe

## Updates

When new container versions come out:

```bash
# Check what versions are available
podman pull postgres:16-alpine

# Test locally first
bash scripts/rebuild-from-scratch.sh

# Verify it works
curl http://localhost/

# Watch for issues over the next day
podman logs -f zabbix-server
podman stats
```

## Resources

- [Podman Security Docs](https://podman.io/docs/podman/security)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Trivy vulnerability scanner](https://github.com/aquasecurity/trivy)
