# Security Policy

## Password Protection

This project follows best practices for managing sensitive information:

1.  **Environment Variables**: All passwords and sensitive configurations are managed through `.env` files and environment variables.
2.  **Docker Secrets**: Sensitive database credentials (Postgres user and password) are managed using Docker Secrets.
3.  **Git Ignore**: The `.gitignore` file is configured to prevent sensitive files (`.env*`, `.POSTGRES*`) from being committed to the repository.
4.  **Example Files**: Template files (`.example`) are provided for users to create their own local configurations without exposing them to the public.

## Local Setup

To set up the project securely on your local machine:

1.  Copy all `.example` files to their respective filenames (removing the `.example` suffix).
2.  Update the values in the new files with your own secure passwords and usernames.
3.  Ensure that these files are NOT committed to your version control system.

## Reporting a Vulnerability

If you discover a security vulnerability within this project, please report it privately. Do not open a public issue.
