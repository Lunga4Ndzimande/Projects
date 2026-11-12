# SQL Server Monitoring - Zabbix + Percona PMM

Local monitoring setup for SQL Server Always On using Zabbix and Percona PMM.

## Architecture
```
sql-primary   (port 1433) ─→ Zabbix Agent ─→ Zabbix Server ─→ Zabbix Web UI (port 8080)
sql-secondary (port 1434) ─→ Zabbix Agent ─/
                                              
sql-primary   (port 1433) ─→ Percona PMM Client ─→ PMM Server (port 8443)
sql-secondary (port 1434) ─→ Percona PMM Client ─/
```

## Access

| Tool          | URL                        | Username | Password  |
|--------------|----------------------------|----------|-----------|
| Zabbix UI    | http://localhost:8080      | Admin    | zabbix    |
| Percona PMM  | https://localhost:8443     | admin    | admin     |

## Start Everything
```bash
docker compose up -d
```

## Stop Everything
```bash
docker compose down
```

## What Each Tool Does

### Zabbix
- Monitors server health (CPU, memory, disk)
- Sends alerts when something goes wrong
- On-call alerting (like incident.io at Katosis)
- Tracks SQL Server availability

### Percona PMM
- Monitors database performance
- Shows slow queries
- Tracks replication lag between PRIMARY and SECONDARY
- Query analytics dashboard
