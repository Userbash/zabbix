#!/usr/bin/env bash

find /home/alex/zabbix/config/dump/* -mtime +30 -exec rm -rf  {} \;
docker-compose exec postgres-server pg_dump -U postgres zabbix > /home/alex/zabbix/config/dump/dump_$(date +%Y-%m-%d_%H_%M_%S).sql
