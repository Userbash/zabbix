# 🛡️ Security Policy & Docker Secrets Management

> **Last Updated**: March 15, 2026  
> **Status**: Production Ready

## Overview

This project implements industry best practices for managing sensitive credentials in containerized environments:

✅ **No hardcoded passwords** - All credentials use Docker Secrets  
✅ **Git-protected secrets** - `.gitignore` prevents accidental commits  
✅ **Template-based setup** - `.example` files guide configuration  
✅ **Permission-controlled files** - Secret files use 600 permissions  

## Password Protection Strategy

### 1. Environment Variables (Non-Sensitive Only)
- `.env_db_pgsql` - Database host, port, version
- `.env_srv` - Zabbix server settings (monitoring config)
- `.env_web` - Web server settings (Nginx config)
- ✅ **Safe to commit to version control**

### 2. Docker Secrets (Sensitive Data)
**Files to manage separately (NOT in git):**
```
.POSTGRES_USER          # PostgreSQL username
.POSTGRES_PASSWORD      # PostgreSQL password
.GF_ROOT_PASSWORD       # Grafana admin password
.GF_DATABASE_PASSWORD   # Grafana database password
.GF_SESSION_PASSWORD    # Grafana session encryption key
.GF_AWS_SECRET_KEY      # Grafana AWS integration (optional)
```

**Permissions**: These files MUST have 600 permissions
```bash
chmod 600 .POSTGRES_* .GF_*
```

### 3. Docker Secrets Implementation
Services use `_FILE` suffix variables to reference secret files:
```yaml
secrets:
  - POSTGRES_USER
  - POSTGRES_PASSWORD
environment:
  POSTGRES_USER_FILE: /run/secrets/POSTGRES_USER
  POSTGRES_PASSWORD_FILE: /run/secrets/POSTGRES_PASSWORD
```

### Git Protection
`.gitignore` prevents secret files from being tracked:
```
# Secrets - NEVER commit these!
.POSTGRES_*
.GF_*
.env*          # Also env files created from .example
!*.example      # But DO commit the example/template files
```

## Setup Instructions

### Quick Start
```bash
# 1. Copy environment templates
cp .env_*.example .env_*

# 2. Create secret files (interactive):
# Option A: Manual setup
echo "your_secure_password" > .POSTGRES_PASSWORD
echo "postgres" > .POSTGRES_USER
chmod 600 .POSTGRES_*

# Option B: Use setup script (if available)
./init-secrets.sh

# 3. Verify permissions
ls -la .POSTGRES_* .GF_*
# Should show: -rw------- (600)

# 4. Start services
docker compose up -d

# 5. Verify secrets are working
docker compose ps
docker compose logs zabbix-server-pgsql
```

### Generated Secret Files Template
See these .example files for templates:
- `.POSTGRES_PASSWORD.example` → `.POSTGRES_PASSWORD`
- `.POSTGRES_USER.example` → `.POSTGRES_USER`
- `.GF_ROOT_PASSWORD.example` → `.GF_ROOT_PASSWORD`
- `.GF_DATABASE_PASSWORD.example` → `.GF_DATABASE_PASSWORD`
- `.GF_SESSION_PASSWORD.example` → `.GF_SESSION_PASSWORD`

## Best Practices

### DO ✅
- Use `chmod 600` for all secret files
- Use environment templates (`.env_*.example`)
- Create secrets file locally AFTER cloning
- Use Docker Secrets in production
- Rotate passwords regularly (change in `.POSTGRES_*` and `.GF_*`)
- Review `.gitignore` before first commit

### DON'T ❌
- Never commit `.POSTGRES_*` or `.GF_*` files
- Never hardcode passwords in code
- Never share secret files in pull requests
- Never print secrets in logs
- Never store secrets in environment variables (use files + secrets)

## Verification Checklist

Before starting containers:
```bash
# 1. Check git will ignore secrets
git check-ignore .POSTGRES_PASSWORD .GF_ROOT_PASSWORD

# 2. Verify file permissions
ls -la | grep "600.*\\.POSTGRES_\\|600.*\\.GF_"

# 3. Verify no secrets in git history
git log --all --source -S "postgres" -- "*.md" "*.yaml"

# 4. Validate docker-compose.yaml
docker compose config > /dev/null && echo "✓ Valid"
```

## Incident Response

### If a Secret Was Committed
1. **Immediately rotate the password** in production
2. **Remove from git history**:
   ```bash
   git filter-branch --tree-filter 'rm -f .POSTGRES_PASSWORD' HEAD
   git push origin --force-with-lease
   ```
3. **Update .gitignore** if not in place
4. **Force password update** in all systems

### If Secrets Were Exposed
1. Change all passwords immediately
2. Check docker history for exposure
3. Review all access logs
4. Create new credentials in all .POSTGRES_* / .GF_* files

## Reporting a Vulnerability

If you discover a security vulnerability within this project, please report it privately. Do not open a public issue.
