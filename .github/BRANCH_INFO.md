# Branch Information

## Main Branches

### `master` (Stable/Production)
- **Status**: Production Ready
- **Latest Tag**: v1.0.0
- **Purpose**: Stable releases for production deployment
- **Update Frequency**: Tagged releases only
- **Deployment**: Recommended for production environments

**Key commits**:
- Docker Secrets integration for all sensitive credentials
- Comprehensive security documentation
- Full Docker Compose and Podman support
- Health checks for all 8 services

### `main` (Development)
- **Status**: Active Development
- **Purpose**: Main development branch
- **Update Frequency**: Regular commits, feature branches merged here
- **Deployment**: Test/staging environments only

**Recent changes**:
- Infrastructure refactoring
- Dockerfile improvements
- GitHub Actions CI/CD integration

## Release Process

1. **Feature branches** → PR → `main` (review & test)
2. **When ready for release** → Merge to `main`
3. **Create tagged release** → `docker compose up -d` & test
4. **Merge to `master`** → Tag with version (v1.x.x)
5. **Push both branches + tags** to origin

## Tags

- **v1.0.0** - First production release
  - Docker Secrets infrastructure
  - 8 services with healthchecks
  - Security documentation

## Remote Repositories

### Origin (Primary)
- URL: `https://github.com/Userbash/Zabbix.git`
- Access: Push/Pull

## Setup for Contributors

```bash
# Clone repository
git clone https://github.com/Userbash/Zabbix.git zabbix
cd zabbix

# Create feature branch from main
git checkout main
git pull origin main
git checkout -b feature/your-feature-name

# Work on feature...

# Push and create PR
git push origin feature/your-feature-name
# Create PR on GitHub: https://github.com/Userbash/Zabbix/pull/new/...
```

## Security

- All branches have `.gitignore` protecting `.POSTGRES_*` and `.GF_*` files
- Docker Secrets are never committed
- See `SECURITY.md` for detailed security policies

## Version History

| Version | Branch | Release Date | Status |
|---------|--------|--------------|--------|
| v1.0.0  | master | March 15, 2026 | Production |

---

**Last Updated**: March 15, 2026  
**Maintainer**: Userbash/Sanya
