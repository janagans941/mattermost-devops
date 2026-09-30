# Mattermost DevOps Project --- Complete Deployment, Operations, Monitoring, Backup, Security & CI Documentation

**Project:** Mattermost DevOps\
**Repository:** `janagans941/mattermost-devops`\
**Branch:** `main`\
**Environment:** Windows + WSL2 + Ubuntu 24.04.4 LTS\
**Project directory:** `~/projects/mattermost`

------------------------------------------------------------------------

## 1. Project Overview

This project implements a complete self-hosted Mattermost DevOps
environment with:

-   Mattermost Team Edition
-   PostgreSQL 16
-   Docker Compose
-   Nginx reverse proxy
-   HTTPS/TLS
-   WebSocket/realtime support
-   Prometheus monitoring
-   Grafana dashboards
-   Loki log aggregation
-   Grafana Alloy log collection
-   Alertmanager
-   Mattermost alert notifications
-   cAdvisor container monitoring
-   Backup and restore automation
-   Disaster recovery procedures
-   Security hardening
-   Bash administration automation
-   Git/GitHub version control
-   GitHub Actions CI validation

### High-level architecture

``` text
                         Browser
                            |
                            | HTTPS :443
                            v
                    +----------------+
                    |     Nginx      |
                    | Reverse Proxy  |
                    | TLS / WSS      |
                    +-------+--------+
                            |
                            | HTTP :8065
                            v
                    +----------------+
                    |   Mattermost   |
                    | Team Edition    |
                    +-------+--------+
                            |
                            | PostgreSQL
                            v
                    +----------------+
                    |  PostgreSQL 16  |
                    +----------------+


Monitoring:

 Docker Containers
       |
       +---- cAdvisor
       |
       +---- Alloy ----> Loki
       |
       +---- Prometheus
       |
       +---- Alertmanager ----> Mattermost #alerts
       |
       +---- Grafana


CI/CD:

Developer
   |
   v
Git
   |
   v
GitHub main
   |
   v
GitHub Actions
   |
   +---- Bash syntax
   +---- ShellCheck
   +---- git diff --check
   +---- Docker Compose validation
```

------------------------------------------------------------------------

# 2. Environment

## 2.1 Host environment

The project was developed on:

``` text
Windows
WSL2
Ubuntu 24.04.4 LTS
```

Important environment versions used during the project:

``` bash
docker --version
docker compose version
git --version
```

Expected project environment:

``` text
Docker       29.7.1
Docker Compose 5.3.1
Git          2.43.0
```

Check:

``` bash
cat /etc/os-release
docker --version
docker compose version
git --version
```

------------------------------------------------------------------------

# 3. Project Directory

Main project directory:

``` bash
cd ~/projects/mattermost
```

Expected structure:

``` text
mattermost/
├── .git/
├── .gitignore
├── docker-compose.yml
├── config/
├── data/
├── logs/
├── plugins/
├── client-plugins/
├── bleve-indexes/
├── monitoring/
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   └── rules/
│   ├── alertmanager/
│   │   ├── alertmanager.yml
│   │   └── mattermost-webhook-url.example
│   ├── loki/
│   │   └── loki-config.yml
│   └── alloy/
│       └── config.alloy
├── scripts/
│   ├── backup-mattermost.sh
│   ├── health-check.sh
│   ├── docker-health.sh
│   ├── diagnose-services.sh
│   ├── mattermost-admin.sh
│   ├── mattermost-send.sh
│   ├── system-summary.sh
│   └── lib/
│       └── common.sh
├── backups/
└── docs/
```

Runtime directories such as Mattermost data and real secrets are
excluded from Git.

------------------------------------------------------------------------

# 4. Docker Compose Architecture

The project uses Docker Compose for the Mattermost application and
supporting monitoring services.

The main services are:

``` text
postgres
mattermost
prometheus
alertmanager
alloy
loki
cadvisor
```

Persistent Docker volumes:

``` text
postgres-data
prometheus-data
loki-data
alertmanager-data
```

Network:

``` text
mattermost-network
```

Check the current Compose configuration:

``` bash
docker compose config -q
```

No output means the configuration is valid.

Start:

``` bash
docker compose up -d
```

Stop:

``` bash
docker compose down
```

Show status:

``` bash
docker compose ps
```

Show logs:

``` bash
docker compose logs --tail=100
```

Follow logs:

``` bash
docker compose logs -f
```

------------------------------------------------------------------------

# 5. PostgreSQL

PostgreSQL is used as Mattermost's application database.

Configuration:

``` text
Image: postgres:16
Container: mattermost-postgres
Database: mattermost
User: mmuser
```

The database is connected internally through the Docker network.

Important connection format:

``` text
postgres://mmuser:mmuser_password@postgres:5432/mattermost
```

The database port is not exposed on the host.

This is intentional.

Check:

``` bash
docker compose ps postgres
```

Enter PostgreSQL:

``` bash
docker exec -it mattermost-postgres \
  psql -U mmuser -d mattermost
```

Check database size:

``` bash
docker exec mattermost-postgres \
  psql -U mmuser -d mattermost \
  -c "SELECT pg_size_pretty(pg_database_size('mattermost'));"
```

Check PostgreSQL version:

``` bash
docker exec mattermost-postgres \
  psql -U mmuser -d mattermost \
  -c "SELECT version();"
```

------------------------------------------------------------------------

# 6. Mattermost

Mattermost container:

``` text
Container: mattermost
Image: mattermost/mattermost-team-edition:latest
Host binding: 127.0.0.1:8065
Container port: 8065
```

The application is deliberately bound only to localhost:

``` yaml
ports:
  - "127.0.0.1:8065:8065"
```

This means users should not directly access Mattermost through:

``` text
http://SERVER-IP:8065
```

Instead, access is through Nginx:

``` text
https://localhost
```

Check:

``` bash
docker inspect mattermost
```

Check state:

``` bash
docker inspect -f '{{.State.Status}}' mattermost
```

Expected:

``` text
running
```

------------------------------------------------------------------------

# 7. Mattermost Health Check

Direct Mattermost API:

``` bash
curl http://127.0.0.1:8065/api/v4/system/ping
```

HTTPS through Nginx:

``` bash
curl -k https://127.0.0.1/api/v4/system/ping
```

The project automation performs both checks.

Run:

``` bash
./scripts/health-check.sh
```

Expected final result:

``` text
Mattermost health check PASSED.
```

------------------------------------------------------------------------

# 8. Mattermost Administration

An administration wrapper was created:

``` bash
./scripts/mattermost-admin.sh
```

Interactive menu:

``` text
1. Health check
2. Docker health
3. Generate diagnostics
4. Create backup
5. System summary
6. Show service status
7. Exit
```

The wrapper also supports non-interactive commands.

Examples:

``` bash
./scripts/mattermost-admin.sh health
```

``` bash
./scripts/mattermost-admin.sh docker
```

``` bash
./scripts/mattermost-admin.sh diagnose
```

``` bash
./scripts/mattermost-admin.sh backup
```

``` bash
./scripts/mattermost-admin.sh summary
```

``` bash
./scripts/mattermost-admin.sh status
```

This is useful for future automation and cron jobs.

------------------------------------------------------------------------

# 9. WebSocket / Realtime

Mattermost realtime communication uses WebSocket.

The project uses Nginx as the external entry point.

Nginx forwards:

``` nginx
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

The proxy uses HTTP/1.1:

``` nginx
proxy_http_version 1.1;
```

Long timeouts are configured:

``` nginx
proxy_read_timeout 600s;
proxy_send_timeout 600s;
```

The realtime endpoint is:

``` text
/api/v4/websocket
```

The secure WebSocket URL is:

``` text
wss://localhost/api/v4/websocket
```

A successful WebSocket upgrade returns:

``` text
HTTP 101 Switching Protocols
```

This was verified during the project.

------------------------------------------------------------------------

# 10. Nginx Reverse Proxy

Nginx is installed as a system service.

Check:

``` bash
sudo systemctl status nginx
```

Test configuration:

``` bash
sudo nginx -t
```

Reload:

``` bash
sudo systemctl reload nginx
```

Restart:

``` bash
sudo systemctl restart nginx
```

Current configuration concept:

``` text
HTTP :80
   |
   +---- redirect
          |
          v
HTTPS :443
   |
   v
127.0.0.1:8065
   |
   v
Mattermost
```

The active configuration contains:

``` nginx
server {
    listen 80;
    listen [::]:80;

    server_name localhost;

    location / {
        return 301 https://localhost$request_uri;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name localhost;

    ssl_certificate /etc/nginx/ssl/mattermost.crt;
    ssl_certificate_key /etc/nginx/ssl/mattermost.key;

    location / {
        proxy_pass http://127.0.0.1:8065;

        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }
}
```

------------------------------------------------------------------------

# 11. HTTPS / TLS

A self-signed certificate is used for the local development environment.

Certificate:

``` text
/etc/nginx/ssl/mattermost.crt
```

Private key:

``` text
/etc/nginx/ssl/mattermost.key
```

Private key permissions:

``` text
600 root root
```

Check:

``` bash
sudo ls -l /etc/nginx/ssl/
```

TLS protocols:

``` text
TLS 1.2
TLS 1.3
```

TLS 1.0 and TLS 1.1 were disabled.

Configured:

``` nginx
ssl_protocols TLSv1.2 TLSv1.3;
```

The certificate was created for:

``` text
localhost
```

The local certificate was valid from September 28, 2026 to September 28,
2027.

Because this is a self-signed development certificate, browsers may
display a certificate warning.

HSTS was intentionally not enabled for this localhost self-signed setup.

------------------------------------------------------------------------

# 12. Monitoring Architecture

Monitoring consists of:

``` text
Node Exporter
       |
       v
System Prometheus
       |
       v
Grafana


Docker
  |
  +--> cAdvisor
  |
  +--> Prometheus


Docker logs
    |
    v
Grafana Alloy
    |
    v
Loki
    |
    v
Grafana


Prometheus
    |
    v
Alertmanager
    |
    v
Mattermost #alerts
```

------------------------------------------------------------------------

# 13. Prometheus

There are two Prometheus-related components in the environment.

### Existing system Prometheus

``` text
127.0.0.1:9090
```

This existing service must not be stopped or replaced.

### Project Docker Prometheus

``` text
127.0.0.1:9091
```

Container:

``` text
mattermost-prometheus
```

This project Prometheus is used for the Docker/Mattermost monitoring
stack.

Check:

``` bash
docker compose ps prometheus
```

Check configuration:

``` bash
docker compose exec prometheus \
  promtool check config /etc/prometheus/prometheus.yml
```

------------------------------------------------------------------------

# 14. Grafana

Grafana runs as a system service.

Port:

``` text
127.0.0.1:3000
```

Check:

``` bash
sudo systemctl status grafana-server
```

Check listening port:

``` bash
ss -lnt | grep 3000
```

Grafana is used for:

-   Prometheus metrics
-   Loki logs
-   Dashboards
-   Monitoring visualization

Grafana was hardened to bind to:

``` text
127.0.0.1
```

------------------------------------------------------------------------

# 15. Loki

Loki provides centralized log storage.

Container:

``` text
mattermost-loki
```

Port:

``` text
127.0.0.1:3100
```

Check:

``` bash
docker compose ps loki
```

Check logs:

``` bash
docker compose logs --tail=100 loki
```

Loki data is stored in:

``` text
loki-data
```

------------------------------------------------------------------------

# 16. Grafana Alloy

Alloy collects Docker container logs and sends them to Loki.

Container:

``` text
mattermost-alloy
```

Port:

``` text
127.0.0.1:12345
```

Configuration:

``` text
monitoring/alloy/config.alloy
```

Check:

``` bash
docker compose ps alloy
```

Logs:

``` bash
docker compose logs --tail=100 alloy
```

------------------------------------------------------------------------

# 17. cAdvisor

cAdvisor provides container-level resource metrics.

Container:

``` text
mattermost-cadvisor
```

Port:

``` text
127.0.0.1:8080
```

Check:

``` bash
docker compose ps cadvisor
```

Logs:

``` bash
docker compose logs --tail=100 cadvisor
```

------------------------------------------------------------------------

# 18. Alertmanager

Alertmanager receives Prometheus alerts.

Container:

``` text
mattermost-alertmanager
```

Port:

``` text
127.0.0.1:9093
```

Configuration:

``` text
monitoring/alertmanager/alertmanager.yml
```

Alert flow:

``` text
Prometheus
    |
    | alert
    v
Alertmanager
    |
    | webhook
    v
Mattermost
    |
    v
#alerts
```

The Mattermost webhook URL is stored separately and is not committed to
Git.

------------------------------------------------------------------------

# 19. Alertmanager Secret Handling

The real webhook file is:

``` text
monitoring/alertmanager/mattermost-webhook-url
```

The example file is:

``` text
monitoring/alertmanager/mattermost-webhook-url.example
```

The real secret must never be committed.

Example:

``` text
https://localhost/hooks/REPLACE_WITH_WEBHOOK_ID
```

is only a placeholder.

The actual webhook URL must remain private.

Permissions used:

``` bash
sudo chown dev:65534 monitoring/alertmanager/mattermost-webhook-url
sudo chmod 640 monitoring/alertmanager/mattermost-webhook-url
```

Expected:

``` text
-rw-r----- 1 dev nogroup
```

------------------------------------------------------------------------

# 20. Alert Testing

A Mattermost-down alert was tested.

The test verified:

``` text
Mattermost stopped
      |
      v
Prometheus alert
      |
      v
Alertmanager
      |
      v
Mattermost #alerts
```

After Mattermost was restored:

``` text
Mattermost recovered
      |
      v
Prometheus recovery
      |
      v
Alertmanager
      |
      v
Recovery notification
```

Alertmanager metrics showed successful Mattermost notification delivery
and zero failed notification counters during the successful test.

------------------------------------------------------------------------

# 21. Docker Health Automation

Script:

``` text
scripts/docker-health.sh
```

Run:

``` bash
./scripts/docker-health.sh
```

It checks:

1.  Docker daemon
2.  Docker Compose configuration
3.  Every Compose service
4.  Container existence
5.  Container running state

Expected:

``` text
Docker daemon is available.
Docker Compose configuration is valid.
All Docker Compose services are running.
```

------------------------------------------------------------------------

# 22. Diagnostic Automation

Script:

``` text
scripts/diagnose-services.sh
```

Run:

``` bash
./scripts/diagnose-services.sh
```

Reports are stored in:

``` text
logs/diagnostics/
```

Example:

``` text
logs/diagnostics/diagnostic_20260930_035415.log
```

The report contains:

-   Docker version
-   Docker Compose version
-   Compose service status
-   Container state
-   Health state
-   Restart counts
-   Docker disk usage
-   Compose configuration result
-   Recent logs for all project containers

The script retains the latest:

``` text
10 reports
```

Older reports are automatically removed.

------------------------------------------------------------------------

# 23. System Summary Automation

Script:

``` text
scripts/system-summary.sh
```

Run:

``` bash
./scripts/system-summary.sh
```

It reports:

-   Mattermost status
-   Docker Compose services
-   Disk usage
-   Memory usage
-   System load
-   Listening ports
-   Recent diagnostic reports
-   Latest backup

This is useful as a quick operational overview.

------------------------------------------------------------------------

# 24. Backup Architecture

The backup solution uses a portable PostgreSQL logical backup plus
Mattermost file backup.

Database:

``` text
pg_dump -Fc
```

Files:

``` text
tar.gz
```

Backup contents:

``` text
PostgreSQL database
Mattermost config
Mattermost data
Mattermost plugins
Mattermost client plugins
Mattermost Bleve indexes
```

The PostgreSQL Docker volume is not treated as the primary portable
database backup.

------------------------------------------------------------------------

# 25. Backup Script

Script:

``` text
scripts/backup-mattermost.sh
```

Run:

``` bash
./scripts/backup-mattermost.sh
```

Backup directories use timestamps:

``` text
backups/YYYY-MM-DD_HH-MM-SS/
```

Example:

``` text
backups/2026-09-29_10-28-05/
```

A successful backup contains:

``` text
mattermost-db.dump
mattermost-files.tar.gz
SHA256SUMS
backup-manifest.txt
```

------------------------------------------------------------------------

# 26. PostgreSQL Backup

The database backup uses:

``` bash
docker exec mattermost-postgres \
    pg_dump \
    -U mmuser \
    -d mattermost \
    -Fc \
    > mattermost-db.dump
```

Custom format is useful because it can be restored using:

``` bash
pg_restore
```

Validate:

``` bash
pg_restore -l mattermost-db.dump
```

------------------------------------------------------------------------

# 27. Mattermost File Backup

The file backup uses:

``` bash
sudo tar \
    --numeric-owner \
    -czf mattermost-files.tar.gz \
    config \
    data \
    plugins \
    client-plugins \
    bleve-indexes
```

Ownership is preserved.

The backup process also changes the resulting archive ownership so the
backup file is manageable by the project user.

------------------------------------------------------------------------

# 28. Backup Integrity

The backup process validates:

### PostgreSQL

``` bash
pg_restore -l
```

### Gzip archive

``` bash
gzip -t mattermost-files.tar.gz
```

### SHA-256

``` bash
sha256sum -c SHA256SUMS
```

All three checks are performed automatically.

------------------------------------------------------------------------

# 29. Backup Manifest

Each backup contains:

``` text
backup-manifest.txt
```

It records:

-   Backup timestamp
-   Application
-   Database name
-   Database user
-   PostgreSQL container
-   PostgreSQL version
-   Database size
-   Backup components
-   Backup file sizes
-   Validation results
-   Ownership information
-   Backup notes

------------------------------------------------------------------------

# 30. Restore Testing

A complete restore test was performed using an isolated PostgreSQL
database and temporary Mattermost instance.

The restore test verified:

``` text
99 tables
5 users
1 team
13 channels
31 posts
```

The temporary Mattermost instance became healthy.

API login was also tested.

The temporary test environment was then cleaned up.

This proves that the backup is not merely being created; it has also
been tested as a restore source.

------------------------------------------------------------------------

# 31. Disaster Recovery

The disaster recovery documentation covers:

``` text
Database restoration
File restoration
Configuration restoration
PostgreSQL validation
Mattermost startup
API validation
Data verification
Recovery cleanup
```

The recommended recovery principle is:

``` text
1. Protect current state
2. Restore database
3. Restore Mattermost files
4. Start services
5. Validate Mattermost
6. Validate API
7. Validate realtime
8. Validate monitoring
9. Validate alerts
```

Do not delete a working environment before establishing a recoverable
restore point.

------------------------------------------------------------------------

# 32. Security Hardening

Security work completed includes:

### Mattermost

``` text
127.0.0.1:8065
```

### Docker Prometheus

``` text
127.0.0.1:9091
```

### Alertmanager

``` text
127.0.0.1:9093
```

### Alloy

``` text
127.0.0.1:12345
```

### cAdvisor

``` text
127.0.0.1:8080
```

### Loki

``` text
127.0.0.1:3100
```

### System Prometheus

``` text
127.0.0.1:9090
```

### Node Exporter

``` text
127.0.0.1:9100
```

### Grafana

``` text
127.0.0.1:3000
```

Only Nginx is intentionally exposed through:

``` text
80
443
```

------------------------------------------------------------------------

# 33. Current Port Map

Current intended listening ports:

``` text
127.0.0.1:3000   Grafana
0.0.0.0:443      Nginx HTTPS
0.0.0.0:80       Nginx HTTP
127.0.0.1:8080   cAdvisor
127.0.0.1:8065   Mattermost
127.0.0.1:3100   Loki
127.0.0.1:9100   Node Exporter
127.0.0.1:9093   Alertmanager
127.0.0.1:9091   Docker Prometheus
127.0.0.1:9090   System Prometheus
127.0.0.1:12345  Alloy
```

No host PostgreSQL port:

``` text
5432
```

is exposed.

------------------------------------------------------------------------

# 34. Port Verification

Use:

``` bash
ss -lnt
```

For a specific port:

``` bash
ss -lnt | grep 8065
```

For all relevant ports:

``` bash
ss -lnt | grep -E '80|443|3000|8065|8080|9090|9091|9093|9100|12345|3100'
```

The important security property is that backend/monitoring services use
`127.0.0.1`.

------------------------------------------------------------------------

# 35. WSL2 Network Review

The environment uses:

``` text
Windows
  |
  v
WSL2
  |
  v
Ubuntu
```

WSL2 information was reviewed, including:

-   WSL version
-   Kernel
-   WSL IP
-   Gateway
-   Windows TCP listeners
-   Windows Firewall profiles
-   Hyper-V network configuration
-   WSL-specific firewall rules

The relevant application ports were found to be loopback-bound.

No additional UFW installation was performed.

No unnecessary iptables changes were introduced.

This avoided adding another firewall layer without a demonstrated
requirement.

------------------------------------------------------------------------

# 36. Existing System Monitoring

The project intentionally preserved existing system monitoring services.

These include:

``` text
Prometheus :9090
Node Exporter :9100
Grafana :3000
```

They were not replaced by the Docker monitoring stack.

This is important when troubleshooting the machine because there are
separate system-level and project-level monitoring components.

------------------------------------------------------------------------

# 37. Bash Automation Standards

The scripts use:

``` bash
set -Eeuo pipefail
```

The shared library is:

``` text
scripts/lib/common.sh
```

It provides:

``` text
timestamp()
log_info()
log_success()
log_warn()
log_error()
require_command()
cleanup_on_exit()
```

Scripts use absolute project paths derived from their own location
instead of depending on the caller's current directory.

------------------------------------------------------------------------

# 38. ShellCheck

All project shell scripts were checked with ShellCheck.

Command:

``` bash
for script in scripts/*.sh scripts/lib/*.sh; do
    shellcheck -x -P scripts "$script"
done
```

Result:

``` text
PASSED
```

No ShellCheck errors remained after the final fixes.

------------------------------------------------------------------------

# 39. Bash Syntax Validation

All scripts were checked using:

``` bash
for script in scripts/*.sh scripts/lib/*.sh; do
    bash -n "$script"
done
```

Result:

``` text
PASSED
```

------------------------------------------------------------------------

# 40. Git Diff Validation

Run:

``` bash
git diff --check
```

This checks for common whitespace problems.

Result:

``` text
PASSED
```

------------------------------------------------------------------------

# 41. Git Repository

Repository:

``` text
https://github.com/janagans941/mattermost-devops.git
```

Main branch:

``` text
main
```

Check:

``` bash
git branch
```

Check remote:

``` bash
git remote -v
```

Check status:

``` bash
git status --short
```

------------------------------------------------------------------------

# 42. Important Git Commits

Important project milestones include:

``` text
92d0d57 Initial Mattermost DevOps project

fcbfc52 Add Mattermost backup automation

819aa54 Add Mattermost disaster recovery documentation

a143354 Harden Docker service port bindings

f302473 Add Mattermost health check automation

701953e Add Mattermost diagnostic automation

9b38760 Add Mattermost administration wrapper

bb79357 Add non-interactive administration commands

6182dbb Add diagnostic report retention

99af00c Add Mattermost system summary automation

50f7066 Add GitHub Actions CI validation
```

The current branch is synchronized with GitHub:

``` text
50f7066 (HEAD -> main, origin/main)
Add GitHub Actions CI validation
```

------------------------------------------------------------------------

# 43. GitHub Actions CI

Workflow:

``` text
.github/workflows/ci.yml
```

Workflow name:

``` text
Mattermost CI
```

It runs on:

``` text
push to main
pull_request to main
```

Pipeline:

``` text
Checkout repository
        |
        v
Install ShellCheck
        |
        v
Bash syntax validation
        |
        v
ShellCheck
        |
        v
git diff --check
        |
        v
Docker Compose validation
```

Workflow configuration:

``` yaml
name: Mattermost CI

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

jobs:
  validate:
    name: Validate Mattermost project
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install shellcheck
        run: |
          sudo apt-get update
          sudo apt-get install -y shellcheck

      - name: Validate Bash syntax
        run: |
          set -e

          for script in scripts/*.sh scripts/lib/*.sh; do
            echo "Checking Bash syntax: $script"
            bash -n "$script"
          done

      - name: Run ShellCheck
        run: |
          set -e

          for script in scripts/*.sh scripts/lib/*.sh; do
            echo "Running ShellCheck: $script"
            shellcheck -x -P scripts "$script"
          done

      - name: Check Git diff
        run: |
          git diff --check

      - name: Validate Docker Compose
        run: |
          docker compose config -q
```

------------------------------------------------------------------------

# 44. GitHub Actions Successful Run

The workflow was pushed successfully after correcting the GitHub
Personal Access Token permission.

The required classic PAT scope was:

``` text
workflow
```

The push then succeeded:

``` text
99af00c..50f7066 main -> main
```

GitHub Actions subsequently showed:

``` text
Mattermost CI #1
Commit: 50f7066
Branch: main
Status: Passed
Duration: 18 seconds
```

This confirms the CI workflow executed successfully on GitHub.

------------------------------------------------------------------------

# 45. GitHub Token Security

The GitHub Personal Access Token must never be placed in:

-   Git repository
-   shell script
-   Docker Compose file
-   documentation
-   screenshots
-   chat messages
-   `.env` committed to Git

Only the required GitHub permissions should be granted.

The token should be treated like a password.

------------------------------------------------------------------------

# 46. .gitignore

Runtime and secret material is excluded from Git.

Important ignored content includes:

``` text
bleve-indexes/
client-plugins/
config/
data/
logs/
plugins/
backups/
.env
```

The real Alertmanager webhook secret is ignored.

The safe example remains tracked:

``` text
monitoring/alertmanager/mattermost-webhook-url.example
```

------------------------------------------------------------------------

# 47. Common Daily Commands

Go to project:

``` bash
cd ~/projects/mattermost
```

Show services:

``` bash
docker compose ps
```

Health:

``` bash
./scripts/health-check.sh
```

Docker health:

``` bash
./scripts/docker-health.sh
```

System summary:

``` bash
./scripts/system-summary.sh
```

Diagnostics:

``` bash
./scripts/diagnose-services.sh
```

Backup:

``` bash
./scripts/backup-mattermost.sh
```

All-in-one menu:

``` bash
./scripts/mattermost-admin.sh
```

------------------------------------------------------------------------

# 48. Troubleshooting --- Mattermost Not Loading

First:

``` bash
docker compose ps
```

Then:

``` bash
./scripts/health-check.sh
```

Check Mattermost logs:

``` bash
docker compose logs --tail=100 mattermost
```

Check PostgreSQL:

``` bash
docker compose logs --tail=100 postgres
```

Check Nginx:

``` bash
sudo nginx -t
sudo systemctl status nginx
```

Check ports:

``` bash
ss -lnt
```

Check direct Mattermost:

``` bash
curl http://127.0.0.1:8065/api/v4/system/ping
```

Check HTTPS:

``` bash
curl -k https://127.0.0.1/api/v4/system/ping
```

------------------------------------------------------------------------

# 49. Troubleshooting --- Realtime Disconnected

Check Mattermost:

``` bash
docker compose ps mattermost
```

Check WebSocket through Nginx.

Browser developer tools can also be used to inspect:

``` text
wss://localhost/api/v4/websocket
```

The expected WebSocket upgrade is:

``` text
101 Switching Protocols
```

Check Nginx configuration:

``` bash
sudo nginx -t
```

Verify:

``` nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_read_timeout 600s;
proxy_send_timeout 600s;
```

------------------------------------------------------------------------

# 50. Troubleshooting --- PostgreSQL

Check:

``` bash
docker compose ps postgres
```

Logs:

``` bash
docker compose logs --tail=100 postgres
```

Test:

``` bash
docker exec mattermost-postgres \
  pg_isready -U mmuser -d mattermost
```

Enter database:

``` bash
docker exec -it mattermost-postgres \
  psql -U mmuser -d mattermost
```

------------------------------------------------------------------------

# 51. Troubleshooting --- Docker Disk Usage

Check:

``` bash
docker system df
```

Detailed:

``` bash
docker system df -v
```

Check host filesystem:

``` bash
df -h
```

Check Docker directory:

``` bash
sudo du -xhd1 /var/lib/docker | sort -h
```

Remove unused dangling images only when appropriate:

``` bash
docker image prune -f
```

Do not blindly run:

``` bash
docker system prune -a --volumes
```

on a production environment.

Always understand what will be deleted first.

------------------------------------------------------------------------

# 52. Troubleshooting --- Diagnostic Report

Run:

``` bash
./scripts/diagnose-services.sh
```

Then:

``` bash
ls -lh logs/diagnostics/
```

Open the latest report:

``` bash
latest="$(
    find logs/diagnostics \
        -maxdepth 1 \
        -type f \
        -name 'diagnostic_*.log' \
        -printf '%T@ %p\n' |
    sort -nr |
    head -1 |
    cut -d' ' -f2-
)"

less "$latest"
```

------------------------------------------------------------------------

# 53. Troubleshooting --- Nginx

Check:

``` bash
sudo nginx -t
```

Status:

``` bash
sudo systemctl status nginx
```

Error log:

``` bash
sudo tail -f /var/log/nginx/error.log
```

Access log:

``` bash
sudo tail -f /var/log/nginx/access.log
```

Restart only when necessary:

``` bash
sudo systemctl restart nginx
```

Prefer reload for configuration changes:

``` bash
sudo systemctl reload nginx
```

------------------------------------------------------------------------

# 54. Troubleshooting --- TLS

Check certificate:

``` bash
openssl x509 \
  -in /etc/nginx/ssl/mattermost.crt \
  -noout \
  -subject \
  -issuer \
  -dates \
  -ext subjectAltName
```

Check HTTPS:

``` bash
curl -k -I https://localhost
```

Check TLS 1.2:

``` bash
openssl s_client \
  -connect localhost:443 \
  -tls1_2
```

Check TLS 1.3:

``` bash
openssl s_client \
  -connect localhost:443 \
  -tls1_3
```

------------------------------------------------------------------------

# 55. Troubleshooting --- GitHub Actions

Check local status:

``` bash
git status --short
```

Check latest commit:

``` bash
git log -2 --oneline
```

Push:

``` bash
git push origin main
```

If GitHub rejects workflow changes with a message about `workflow`
scope, the Personal Access Token needs the required workflow permission.

Never paste the token into chat.

After a successful push:

``` bash
git status --short
git log -2 --oneline
```

Expected:

``` text
50f7066 (HEAD -> main, origin/main) ...
```

Then check GitHub:

``` text
Actions -> Mattermost CI
```

------------------------------------------------------------------------

# 56. Production Considerations

This project is primarily a development/lab/portfolio implementation.

Before production deployment, review:

-   Replace self-signed TLS with a trusted certificate.
-   Use a real DNS hostname.
-   Use strong unique database credentials.
-   Store secrets in a proper secret manager.
-   Restrict inbound network access.
-   Review Mattermost security settings.
-   Define backup retention.
-   Store backups on a separate system.
-   Encrypt backups where required.
-   Test disaster recovery periodically.
-   Monitor disk space.
-   Monitor database health.
-   Monitor certificate expiry.
-   Configure alert routing.
-   Review GitHub repository permissions.
-   Pin container image versions where appropriate.
-   Establish an update/patch process.

------------------------------------------------------------------------

# 57. Operational Runbook

## Daily

``` bash
cd ~/projects/mattermost
./scripts/health-check.sh
```

Check:

``` bash
docker compose ps
```

## Before major changes

Create a backup:

``` bash
./scripts/backup-mattermost.sh
```

Check:

``` bash
ls -lh backups/
```

## After major changes

Run:

``` bash
./scripts/health-check.sh
./scripts/docker-health.sh
```

Generate diagnostics:

``` bash
./scripts/diagnose-services.sh
```

Check Git:

``` bash
git status --short
git diff --check
```

## After pushing code

Check:

``` text
GitHub -> Actions -> Mattermost CI
```

Confirm the workflow is green.

------------------------------------------------------------------------

# 58. Recovery Runbook

If Mattermost becomes unavailable:

### Step 1

Check:

``` bash
./scripts/health-check.sh
```

### Step 2

Check:

``` bash
docker compose ps
```

### Step 3

Check diagnostics:

``` bash
./scripts/diagnose-services.sh
```

### Step 4

Review:

``` bash
docker compose logs --tail=100 mattermost
docker compose logs --tail=100 postgres
```

### Step 5

If data recovery is required, identify the correct backup:

``` bash
ls -lh backups/
```

Verify:

``` bash
cd backups/<BACKUP_TIMESTAMP>
sha256sum -c SHA256SUMS
```

Then follow the disaster recovery procedure documented for the project.

Do not delete the existing environment until the recovery plan has been
reviewed.

------------------------------------------------------------------------

# 59. Backup Checklist

Before declaring a backup successful:

``` text
[ ] Database dump exists
[ ] Mattermost file archive exists
[ ] pg_restore validation passed
[ ] gzip validation passed
[ ] SHA-256 validation passed
[ ] backup-manifest.txt exists
[ ] Backup directory timestamp is correct
[ ] Backup is outside Git tracking
```

------------------------------------------------------------------------

# 60. Monitoring Checklist

Verify:

``` text
[ ] Mattermost running
[ ] PostgreSQL running
[ ] Prometheus running
[ ] Alertmanager running
[ ] Loki running
[ ] Alloy running
[ ] cAdvisor running
[ ] Grafana running
[ ] Node Exporter running
[ ] System Prometheus running
```

Check:

``` bash
docker compose ps
```

and:

``` bash
sudo systemctl status nginx
sudo systemctl status grafana-server
```

------------------------------------------------------------------------

# 61. Security Checklist

``` text
[ ] Mattermost bound to localhost
[ ] PostgreSQL not exposed on host
[ ] Monitoring services bound to localhost
[ ] Grafana bound to localhost
[ ] Node Exporter bound to localhost
[ ] System Prometheus bound to localhost
[ ] TLS 1.0 disabled
[ ] TLS 1.1 disabled
[ ] TLS 1.2 enabled
[ ] TLS 1.3 enabled
[ ] HTTP redirects to HTTPS
[ ] WebSocket proxy headers configured
[ ] Private TLS key permissions restricted
[ ] Real webhook secret excluded from Git
[ ] Backups excluded from Git
[ ] GitHub PAT not stored in repository
```

------------------------------------------------------------------------

# 62. Git Workflow

Before committing:

``` bash
git status
git diff
git diff --check
```

Run local CI-equivalent checks:

``` bash
for script in scripts/*.sh scripts/lib/*.sh; do
    bash -n "$script"
done
```

``` bash
for script in scripts/*.sh scripts/lib/*.sh; do
    shellcheck -x -P scripts "$script"
done
```

``` bash
docker compose config -q
```

Commit:

``` bash
git add .
git commit -m "Your change description"
```

Push:

``` bash
git push origin main
```

Then verify GitHub Actions.

------------------------------------------------------------------------

# 63. Final Architecture Summary

The completed project follows this operational model:

``` text
                         USERS
                           |
                           | HTTPS
                           v
                    +-------------+
                    |    NGINX    |
                    | 80 -> 443   |
                    | TLS + WSS   |
                    +------+------+
                           |
                           v
                    +-------------+
                    | MATTERMOST  |
                    |    :8065    |
                    +------+------+
                           |
                           v
                    +-------------+
                    | POSTGRESQL  |
                    |    :5432    |
                    +-------------+


       +---------------- MONITORING ----------------+

                    Docker Services
                           |
          +----------------+----------------+
          |                |                |
          v                v                v
       cAdvisor         Alloy            Prometheus
          |                |                |
          |                v                |
          |              Loki              |
          |                |                |
          +----------------+----------------+
                           |
                           v
                        Grafana

Prometheus
    |
    v
Alertmanager
    |
    v
Mattermost #alerts


       +---------------- OPERATIONS ----------------+

       Backup --> PostgreSQL dump + Mattermost files
          |
          v
       Restore testing
          |
          v
       Disaster Recovery


       +---------------- DEVELOPMENT ----------------+

       Git
        |
        v
       GitHub
        |
        v
   GitHub Actions
        |
        +---- Bash syntax
        +---- ShellCheck
        +---- git diff --check
        +---- Compose validation
```

------------------------------------------------------------------------

# 64. Project Completion Status

``` text
Phase 1   Environment / project setup          COMPLETE
Phase 2   Mattermost + PostgreSQL              COMPLETE
Phase 3   Mattermost administration            COMPLETE
Phase 4   Users / teams / channels             COMPLETE
Phase 5   Realtime / WebSocket                 COMPLETE
Phase 6   REST API                              COMPLETE
Phase 7   Docker architecture / troubleshooting COMPLETE
Phase 8   Nginx reverse proxy                  COMPLETE
Phase 9   HTTPS / TLS                          COMPLETE
Phase 10  Prometheus monitoring                COMPLETE
Phase 11  Grafana dashboards                   COMPLETE
Phase 12  Loki logging                         COMPLETE
Phase 13  Alertmanager                         COMPLETE
Phase 14  Backup / restore                     COMPLETE
Phase 15  Disaster recovery                    COMPLETE
Phase 16  Security hardening                   COMPLETE
Phase 17  Bash automation                      COMPLETE
Phase 18  GitHub repository / documentation    COMPLETE
Phase 19  GitHub Actions CI/CD                 COMPLETE
Phase 20  Final documentation                  COMPLETE
```

------------------------------------------------------------------------

# 65. Final Verification Commands

Run the following whenever the entire project needs to be checked:

``` bash
cd ~/projects/mattermost
```

``` bash
docker compose config -q
```

``` bash
./scripts/health-check.sh
```

``` bash
./scripts/docker-health.sh
```

``` bash
./scripts/system-summary.sh
```

``` bash
git status --short
```

``` bash
git log -2 --oneline
```

Expected Git state:

``` text
50f7066 (HEAD -> main, origin/main) Add GitHub Actions CI validation
```

Expected:

``` text
git status --short
```

to produce no output when there are no uncommitted changes.

------------------------------------------------------------------------

# 66. Final Project Result

The project has evolved from a basic Mattermost Docker deployment into a
complete DevOps-oriented platform.

The final implementation includes:

``` text
Application
    Mattermost

Database
    PostgreSQL

Containerization
    Docker
    Docker Compose

Reverse Proxy
    Nginx

Security
    Localhost port binding
    TLS 1.2 / TLS 1.3
    Secret separation

Realtime
    WebSocket / WSS

Monitoring
    Prometheus
    Grafana
    cAdvisor
    Node Exporter

Logging
    Grafana Alloy
    Loki

Alerting
    Alertmanager
    Mattermost notifications

Operations
    Health checks
    Diagnostics
    System summary
    Administration wrapper

Data Protection
    PostgreSQL backups
    File backups
    SHA-256 validation
    Restore testing
    Disaster recovery

Automation
    Bash

Version Control
    Git
    GitHub

CI
    GitHub Actions
    Bash syntax checks
    ShellCheck
    Docker Compose validation
    Git diff validation
```

This document should be treated as the operational reference for the
project. When troubleshooting, start with the health check, then Docker
service status, then diagnostics, and only proceed to recovery when the
evidence indicates that recovery is required.
