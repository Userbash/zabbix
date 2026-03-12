#!/usr/bin/env bash
# Zabbix Backup Script

# Create backup directory if it doesn't exist
mkdir -p backups

# Remove backups older than 30 days
find backups/ -mtime +30 -exec rm -rf {} \;

# Execute pg_dump in the postgres container
docker compose exec -T postgres pg_dump -U zabbix zabbix > backups/dump_$(date +%Y-%m-%d_%H_%M_%S).sql
