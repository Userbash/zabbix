# Publishing Checklist

## Goal
Prepare the repository for public publishing without leaking secrets.

## 1) Local secrets
Keep secrets out of git. Use example files for documentation.

- Use `.env*.example` templates
- Use secret files like `.POSTGRES_USER` and `.GF_DATABASE_PASSWORD`
- Do not commit real values

## 2) Git hygiene
This repository includes:
- `.gitignore` rules for local secrets
- `gitleaks` pre-commit hook
- CI secret scan workflow

Run locally:
```bash
pre-commit install
pre-commit run --all-files
```

## 3) Optional encryption (sops/age)
If you need to keep secrets in git, encrypt them.

Example (age):
```bash
age-keygen -o age.key
sops --encrypt --age <public-key> .env.prod > .env.prod.enc
```

## 4) Secret manager integration
If you use a secret manager (Vault/1Password/Bitwarden), map secrets to:
- `.POSTGRES_USER`
- `.POSTGRES_PASSWORD`
- `.GF_DATABASE_USER`
- `.GF_DATABASE_PASSWORD`
- `.GF_SESSION_PROVIDER_CONFIG`

## 5) Final pre-publish checks
- Ensure `.env` and secret files are not tracked
- Run `gitleaks` locally
- Review CI `secret-scan` status
