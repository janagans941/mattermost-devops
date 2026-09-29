# Phase 15 — Disaster Recovery

## 1. Overview

This document defines the Disaster Recovery (DR) procedure for the Mattermost DevOps project.

The objective is to provide a repeatable procedure to rebuild the Mattermost application and restore its application data after a failure, data loss, container loss, Docker volume loss, or replacement of the host environment.

The recovery design uses two primary sources:

1. GitHub repository
   - Docker Compose configuration
   - Monitoring configuration
   - Alertmanager configuration
   - Loki configuration
   - Grafana Alloy configuration
   - Prometheus configuration and alert rules
   - Backup automation scripts

2. Mattermost restore point
   - PostgreSQL logical database dump
   - Mattermost configuration
   - Mattermost application data
   - Mattermost plugins
   - Mattermost client plugins
   - Mattermost Bleve indexes

The recovery procedure has been tested using an isolated PostgreSQL database and an isolated Mattermost container without modifying the running production/project environment.

## 2. Current Architecture

The current Mattermost environment consists of:

- Nginx reverse proxy
- Mattermost application
- PostgreSQL database
- Prometheus
- Alertmanager
- Grafana Alloy
- Loki
- cAdvisor

The application flow is:

Browser -> Nginx -> Mattermost -> PostgreSQL

Monitoring flow:

Mattermost/Docker -> Prometheus
Docker -> cAdvisor
Docker -> Grafana Alloy -> Loki
Prometheus -> Alertmanager -> Mattermost #alerts

Nginx runs separately from the Docker Compose stack and provides HTTPS/TLS access to Mattermost.

System-level Prometheus on port 9090 and Node Exporter on port 9100 are separate from the project Docker monitoring stack and must not be stopped or replaced during Mattermost recovery.


---

## 3. Disaster Scenarios

This DR procedure is intended to cover scenarios such as:

- Mattermost container failure
- PostgreSQL container failure
- Loss of Mattermost Docker volumes
- Loss or corruption of Mattermost application files
- Loss or corruption of the Mattermost PostgreSQL database
- Docker environment failure
- Replacement of the host
- Reinstallation of the operating system
- Migration of Mattermost to another server
- Recovery after accidental deletion of application data

A complete host-level disaster may also require recovery of infrastructure outside the Mattermost application backup, including Nginx, TLS certificates, Grafana, system Prometheus, Node Exporter, and other host-level configuration.

## 4. Recovery Strategy

The recovery strategy is:

GitHub Repository
        |
        v
Rebuild configuration
        |
        v
Docker / Docker Compose
        |
        +-------------------+
        |                   |
        v                   v
   PostgreSQL          Mattermost
        |                   |
        v                   v
  DB restore          File restore
        |                   |
        +---------+---------+
                  |
                  v
          Start Mattermost
                  |
                  v
          Health validation
                  |
                  v
          API validation
                  |
                  v
          Application restored

The PostgreSQL database is restored from the portable pg_dump custom-format archive.

The Mattermost application files are restored from the compressed tar archive.

The PostgreSQL Docker volume is not used as the primary database backup source.


---

## 5. Backup Restore Point

The latest verified restore point used during this DR exercise is:

backups/2026-09-29_06-30-22/

Contents:

- SHA256SUMS
- backup-manifest.txt
- mattermost-db.dump
- mattermost-files.tar.gz

Backup sizes:

- mattermost-db.dump: 208K
- mattermost-files.tar.gz: 90M

The backup manifest reports:

- Database: PostgreSQL
- Database Name: mattermost
- Database User: mmuser
- PostgreSQL Container: mattermost-postgres
- PostgreSQL Version: 16.15
- Database Size: 13 MB
- Mattermost File Ownership: UID/GID 2000:2000

## 6. Backup Validation

The restore point contains a SHA-256 checksum file.

Validation command:

cd ~/projects/mattermost/backups/2026-09-29_06-30-22
sha256sum -c SHA256SUMS

Expected result:

mattermost-db.dump: OK
mattermost-files.tar.gz: OK

The latest restore point was independently verified and both checksum validations returned OK.

The automated backup process also validates:

- PostgreSQL archive using pg_restore
- Mattermost file archive using gzip -t
- SHA-256 checksums

## 7. What the Mattermost Application Backup Contains

The Mattermost application backup contains the PostgreSQL database and Mattermost application files.

Database data includes Mattermost users, teams, channels, posts, and other Mattermost database records.

Mattermost application files include:

- config/
- data/
- plugins/
- client-plugins/
- bleve-indexes/

Runtime logs are intentionally excluded from the application backup.

Monitoring data volumes are separate from the Mattermost application backup.


---

## 8. Database Backup Procedure

The Mattermost PostgreSQL database is backed up using PostgreSQL logical backup with pg_dump in custom format.

Manual database backup command:

```bash
docker exec mattermost-postgres \\
  pg_dump -U mmuser -d mattermost -Fc \\
  > backups/mattermost-db.dump
```

The `-Fc` option creates a PostgreSQL custom-format archive.

This format is suitable for restoration using `pg_restore` and allows the database backup to be restored independently of the original PostgreSQL Docker volume.

The database backup should be created before any destructive recovery operation.

## 9. Mattermost File Backup Procedure

Mattermost application files are backed up separately from the PostgreSQL database.

Manual file backup command:

```bash
sudo tar \\
  --numeric-owner \\
  -czf backups/mattermost-files.tar.gz \\
  config data plugins client-plugins bleve-indexes
```

The `--numeric-owner` option preserves the numeric UID/GID values stored in the Mattermost files.

The Mattermost container uses UID/GID 2000:2000 for its application files. Preserving ownership is important when restoring the files to a new or rebuilt Mattermost container.

The file backup intentionally excludes the `logs/` directory because application logs are runtime information and are not required to restore the Mattermost application state.

## 10. Automated Backup Procedure

The automated backup script is stored in:

scripts/backup-mattermost.sh

The script creates timestamped restore points under:

backups/YYYY-MM-DD_HH-MM-SS/

Each restore point contains:

- mattermost-db.dump
- mattermost-files.tar.gz
- SHA256SUMS
- backup-manifest.txt

The script performs backup validation and records the backup metadata in the manifest.

Example execution:

```bash
./scripts/backup-mattermost.sh
```

After creating a backup, verify the generated restore point and checksum file before considering the backup ready for disaster recovery.


---

## 11. Database Restore Procedure

The PostgreSQL database can be restored into a newly created PostgreSQL container or PostgreSQL volume.

The restore procedure used during the DR test was performed against an isolated PostgreSQL container and did not modify the production Mattermost database.

### 11.1 Create an Isolated PostgreSQL Environment

An isolated PostgreSQL volume was created for the restore test:

```bash
docker volume create mattermost-restore-postgres-data
```

An isolated PostgreSQL container was then started using PostgreSQL 16 with a test database and test password.

Example:

```bash
docker run -d \\
  --name mattermost-restore-postgres \\
  -e POSTGRES_USER=mmuser \\
  -e POSTGRES_PASSWORD=restore_test_password \\
  -e POSTGRES_DB=mattermost \\
  -v mattermost-restore-postgres-data:/var/lib/postgresql/data \\
  postgres:16
```

The password above is a test-only password used during the isolated DR validation. It is not the production database password.

### 11.2 Copy the Database Backup

Copy the known-good database archive into the isolated PostgreSQL container:

```bash
docker cp \\
  backups/2026-09-29_06-11-24/mattermost-db.dump \\
  mattermost-restore-postgres:/tmp/mattermost-db.dump
```

### 11.3 Restore the Database

Restore the PostgreSQL custom-format archive using `pg_restore`:

```bash
docker exec mattermost-restore-postgres \\
  pg_restore \\
  -U mmuser \\
  -d mattermost \\
  --no-owner \\
  --no-privileges \\
  /tmp/mattermost-db.dump
```

The `--no-owner` option prevents the restore from attempting to recreate the original object ownership.

The `--no-privileges` option prevents restoration of GRANT/REVOKE statements that may depend on roles not present in the isolated test environment.

### 11.4 Validate the Restored Database

After restoration, verify the number of public tables:

```bash
docker exec mattermost-restore-postgres \\
  psql -U mmuser -d mattermost \\
  -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema=public;"
```

The DR test returned:

```text
99
```

Important Mattermost data was also checked.

The DR test returned:

```text
users: 5
teams: 1
channels: 13
posts: 31
```

These values matched the production database values recorded before the restore test.

This confirmed that the logical database backup could be restored successfully into a fresh PostgreSQL environment.


---

## 12. Mattermost File Restore Procedure

The Mattermost application files are restored from the `mattermost-files.tar.gz` archive.

The file restore should be performed only after confirming that the correct backup restore point has been selected and its SHA-256 checksum has passed validation.

### 12.1 Create the Restore Directory

During the DR validation, the application files were extracted into an isolated directory instead of overwriting the production Mattermost directories.

Example:

```bash
mkdir -p restore-test/mattermost
```

### 12.2 Extract the Mattermost Files

The backup archive was extracted using `sudo` and `--numeric-owner`:

```bash
sudo tar \\
  --numeric-owner \\
  -xzf backups/2026-09-29_06-11-24/mattermost-files.tar.gz \\
  -C restore-test/mattermost
```

The following directories were restored:

- config/
- data/
- plugins/
- client-plugins/
- bleve-indexes/

### 12.3 Verify Restored File Ownership

Mattermost application files use UID/GID 2000:2000.

Ownership can be checked with:

```bash
sudo ls -ln restore-test/mattermost
```

The DR test confirmed that the restored application directories used UID/GID 2000:2000.

The main configuration file was also checked:

```bash
sudo ls -ln restore-test/mattermost/config/config.json
```

The restored `config/config.json` was owned by UID/GID 2000:2000.

### 12.4 Verify Restored Application Data

The DR test confirmed that the restored directory sizes matched the source backup state:

```text
config           32K
 data            52K
 plugins        215M
 client-plugins  26M
 bleve-indexes    4K
```

The restored plugins included:

- mattermost-ai
- com.mattermost.calls
- playbooks

Mattermost user profile data was also present after extraction.

### 12.5 Important Restore Warning

Do not extract a backup directly over a running production Mattermost installation without first planning the recovery procedure.

For a real disaster recovery operation, Mattermost should be stopped before replacing its application files, and the PostgreSQL database should be restored in a controlled sequence.

A separate temporary restore environment is recommended for validation before production recovery whenever the infrastructure allows it.


---

## 13. Start Mattermost After Restore

After the PostgreSQL database and Mattermost application files have been restored, the Mattermost service can be started.

For a production recovery, first confirm that the PostgreSQL service is available and accepting connections.

```bash
docker exec mattermost-postgres pg_isready -U mmuser -d mattermost
```

Expected result:

```text
accepting connections
```

Then start the Mattermost stack:

```bash
docker compose up -d
```

Check the container status:

```bash
docker compose ps
```

Mattermost should eventually report a healthy state.

Check Mattermost logs if the container does not become healthy:

```bash
docker compose logs --tail=100 mattermost
```

The PostgreSQL logs can be checked with:

```bash
docker compose logs --tail=100 postgres
```

## 14. Mattermost Health Validation

After the Mattermost container starts, validate the application through the local HTTP endpoint before testing the Nginx HTTPS endpoint.

Check the Mattermost application:

```bash
curl -I http://localhost:8065
```

A successful response should return HTTP status 200.

The Mattermost system ping API can also be checked:

```bash
curl -s http://localhost:8065/api/v4/system/ping
```

A successful response contains:

```text
"status":"OK"
```

The DR restore test returned HTTP 200 from the isolated Mattermost instance and the `/api/v4/system/ping` endpoint returned status OK.

## 15. HTTPS and Nginx Validation

After the Mattermost application is confirmed healthy, validate the Nginx reverse proxy and HTTPS endpoint.

The production project uses Nginx separately from the Docker Compose stack.

HTTPS validation command:

```bash
curl -k -s -o /dev/null -w "Mattermost HTTPS Status: %{http_code}\\n" https://localhost
```

The verified production environment returned:

```text
Mattermost HTTPS Status: 200
```

The `-k` option is used because the development environment uses a self-signed TLS certificate.

For a production environment with a trusted certificate, certificate validation should be performed normally without `-k`.

## 16. WebSocket / Realtime Validation

Mattermost realtime functionality depends on the WebSocket endpoint.

The verified environment uses the Mattermost WebSocket endpoint:

```text
wss://localhost/api/v4/websocket
```

During the project setup, the WebSocket connection was verified successfully with HTTP status 101 during the WebSocket upgrade.

If the Mattermost web interface loads but realtime features do not work after recovery, check the following components:

- Mattermost container
- Nginx configuration
- WebSocket proxy configuration
- Mattermost SiteURL
- Mattermost WebSocket configuration
- Network connectivity
- Mattermost logs

## 17. PostgreSQL Validation

After recovery, verify that PostgreSQL is accepting connections:

```bash
docker exec mattermost-postgres pg_isready -U mmuser -d mattermost
```

Then verify that the Mattermost database exists:

```bash
docker exec mattermost-postgres \\
  psql -U mmuser -d mattermost -c "SELECT current_database();"
```

The expected database name is:

```text
mattermost
```

For a deeper validation, verify important Mattermost table counts after recovery.

Example:

```bash
docker exec mattermost-postgres \\
  psql -U mmuser -d mattermost -c "SELECT COUNT(*) FROM users;"
```

Additional checks can be performed for teams, channels, and posts.


---

## 18. Monitoring and Observability Recovery

Monitoring services are separate from the core Mattermost database and application backup.

The project monitoring stack contains:

- Prometheus
- Alertmanager
- Grafana Alloy
- Loki
- cAdvisor

Grafana is running as a system service on port 3000 and is separate from the Docker Compose monitoring containers.

The host also contains separate system-level Prometheus and Node Exporter services.

### 18.1 Project Prometheus

Project Prometheus runs in Docker and is exposed on host port 9091.

Check its status:

```bash
docker compose ps prometheus
```

Check Prometheus logs:

```bash
docker compose logs --tail=100 prometheus
```

Prometheus configuration is stored in:

```text
monitoring/prometheus/prometheus.yml
```

Alert rules are stored in:

```text
monitoring/prometheus/rules/
```

### 18.2 Alertmanager

Alertmanager runs in Docker on port 9093.

Check its status:

```bash
docker compose ps alertmanager
```

Check Alertmanager logs:

```bash
docker compose logs --tail=100 alertmanager
```

The Mattermost webhook URL is stored separately and must not be committed to GitHub.

The repository contains only:

```text
monitoring/alertmanager/mattermost-webhook-url.example
```

The real webhook file is ignored by Git.

### 18.3 Loki and Grafana Alloy

Loki stores centralized logs for the project monitoring environment.

Check Loki:

```bash
docker compose ps loki
```

Check Alloy:

```bash
docker compose ps alloy
```

Check their logs if required:

```bash
docker compose logs --tail=100 loki

docker compose logs --tail=100 alloy
```

Loki configuration is stored in:

```text
monitoring/loki/loki-config.yml
```

Alloy configuration is stored in:

```text
monitoring/alloy/config.alloy
```

### 18.4 cAdvisor

cAdvisor provides Docker container metrics.

Check its status:

```bash
docker compose ps cadvisor
```

If cAdvisor is unhealthy, inspect its logs:

```bash
docker compose logs --tail=100 cadvisor
```

### 18.5 System Monitoring Services

The host also contains separate system-level monitoring services.

System Prometheus uses port 9090.

Node Exporter uses port 9100.

These services are not part of the Mattermost Docker Compose stack.

During Mattermost recovery, do not stop, replace, or remove the system-level Prometheus or Node Exporter services unless the recovery procedure specifically requires host-level monitoring recovery.

### 18.6 Monitoring Recovery Principle

Mattermost application recovery should be completed and validated before troubleshooting monitoring services.

The application database and files are the primary Mattermost recovery data.

Monitoring data volumes such as Prometheus, Loki, and Alertmanager storage are separate and should be recovered independently if historical monitoring data is required.


---

## 19. Complete Disaster Recovery Runbook

Use the following sequence when the Mattermost server or Docker environment must be rebuilt.

### Step 1 — Prepare the Host

Install the required host components:

- Ubuntu/Linux
- Docker Engine
- Docker Compose
- Git
- Nginx
- PostgreSQL client tools if required for administration
- Required monitoring packages/services

Verify Docker:

```bash
docker --version
docker compose version
```

Verify Git:

```bash
git --version
```

### Step 2 — Clone the Project Repository

Clone the GitHub repository containing the Mattermost deployment configuration:

```bash
git clone https://github.com/janagans941/mattermost-devops.git
cd mattermost-devops
```

Do not expect the Git repository to contain runtime Mattermost data or database backups because those are intentionally excluded from Git.

### Step 3 — Restore the Backup Files

Copy the selected verified restore point to the new host.

Verify the checksum:

```bash
cd backups/YYYY-MM-DD_HH-MM-SS
sha256sum -c SHA256SUMS
```

Do not continue if the checksum validation fails.

### Step 4 — Prepare Mattermost Directories

Create the Mattermost persistent directories required by the Compose configuration:

```bash
mkdir -p config data logs plugins client-plugins bleve-indexes
```

Stop the Mattermost stack before replacing application files:

```bash
docker compose down
```

### Step 5 — Restore Mattermost Application Files

Extract the verified application backup:

```bash
sudo tar \\
  --numeric-owner \\
  -xzf backups/YYYY-MM-DD_HH-MM-SS/mattermost-files.tar.gz \\
  -C .
```

Verify ownership:

```bash
sudo ls -ln config data plugins client-plugins bleve-indexes
```

The Mattermost application files should retain UID/GID 2000:2000.

### Step 6 — Start PostgreSQL

Start PostgreSQL first:

```bash
docker compose up -d postgres
```

Wait until PostgreSQL accepts connections:

```bash
docker exec mattermost-postgres pg_isready -U mmuser -d mattermost
```

### Step 7 — Restore the PostgreSQL Database

If the database is empty or the original PostgreSQL data has been lost, restore the verified database archive.

Copy the backup into the PostgreSQL container:

```bash
docker cp \\
  backups/YYYY-MM-DD_HH-MM-SS/mattermost-db.dump \\
  mattermost-postgres:/tmp/mattermost-db.dump
```

Restore it:

```bash
docker exec mattermost-postgres \\
  pg_restore \\
  -U mmuser \\
  -d mattermost \\
  --no-owner \\
  --no-privileges \\
  /tmp/mattermost-db.dump
```

For an existing non-empty database, do not blindly run the restore command. First determine whether the database must be recreated or whether a controlled migration/restore procedure is required.

### Step 8 — Start Mattermost

Start the Mattermost service:

```bash
docker compose up -d mattermost
```

Check status:

```bash
docker compose ps mattermost
```

Check logs:

```bash
docker compose logs --tail=100 mattermost
```

### Step 9 — Validate Mattermost

Check the local endpoint:

```bash
curl -I http://localhost:8065
```

Check the system ping API:

```bash
curl -s http://localhost:8065/api/v4/system/ping
```

Confirm that the response contains:

```text
"status":"OK"
```

### Step 10 — Restore Nginx and HTTPS

Restore or recreate the Nginx configuration and TLS certificate configuration for the host.

Validate the Nginx configuration:

```bash
sudo nginx -t
```

Restart Nginx if required:

```bash
sudo systemctl restart nginx
```

Validate HTTPS:

```bash
curl -k -s -o /dev/null -w "Mattermost HTTPS Status: %{http_code}\\n" https://localhost
```

Expected result:

```text
Mattermost HTTPS Status: 200
```

### Step 11 — Validate WebSocket / Realtime

Verify that the Mattermost WebSocket endpoint is available through Nginx:

```text
wss://localhost/api/v4/websocket
```

The WebSocket upgrade should return HTTP status 101.

### Step 12 — Restore Monitoring

Start the project monitoring services:

```bash
docker compose up -d prometheus alertmanager loki alloy cadvisor
```

Verify:

```bash
docker compose ps
```

Check the individual service logs if required.

Recreate the real Alertmanager Mattermost webhook secret from a secure source. Do not copy a real webhook URL into Git.

### Step 13 — Validate Application Data

Log in to Mattermost and verify:

- Users
- Teams
- Channels
- Posts
- Files
- Plugins
- Application configuration
- Realtime messaging

Verify that the expected administrator account can authenticate.

### Step 14 — Final Health Check

Run:

```bash
docker compose ps
```

Then validate:

```bash
docker exec mattermost-postgres pg_isready -U mmuser -d mattermost
curl -k -s -o /dev/null -w "Mattermost HTTPS Status: %{http_code}\\n" https://localhost
```

The recovery should not be considered complete until the application, database, HTTPS endpoint, and realtime functionality have been validated.


---

## 20. Disaster Recovery Test Results

A complete isolated restore test was performed without modifying the production Mattermost database or production Mattermost containers.

### Database Restore Results

The isolated PostgreSQL restore successfully completed.

Validated results:

- Public database tables: 99
- Users: 5
- Teams: 1
- Channels: 13
- Posts: 31

The restored database matched the corresponding production counts recorded before the test.

### Application File Restore Results

The Mattermost application archive was successfully extracted into an isolated restore directory.

Validated directories:

- config/
- data/
- plugins/
- client-plugins/
- bleve-indexes/

The restored files retained UID/GID 2000:2000.

The restored configuration file was present and readable.

The restored plugins included:

- mattermost-ai
- com.mattermost.calls
- playbooks

### Isolated Mattermost Startup Results

A temporary Mattermost container was started against the restored PostgreSQL database and restored application files.

The isolated Mattermost container became healthy.

The application returned:

```text
HTTP 200
```

The system ping API returned:

```text
"status":"OK"
```

An authenticated API login was also successfully tested against the restored Mattermost instance.

### Production Environment Validation

After the isolated restore test was completed, the temporary recovery environment was removed.

The production Mattermost stack remained healthy.

The final production validation returned:

```text
Mattermost HTTPS Status: 200
```

PostgreSQL also returned:

```text
accepting connections
```

## 21. DR Recovery Checklist

Use this checklist during an actual incident.

### Backup

- [ ] Identify the latest verified restore point
- [ ] Verify `SHA256SUMS`
- [ ] Confirm the database archive exists
- [ ] Confirm the Mattermost files archive exists
- [ ] Review `backup-manifest.txt`

### Host

- [ ] Confirm Linux host is available
- [ ] Install Docker
- [ ] Install Docker Compose
- [ ] Install Git
- [ ] Install/configure Nginx
- [ ] Confirm required ports

### PostgreSQL

- [ ] Start PostgreSQL
- [ ] Confirm `pg_isready`
- [ ] Confirm database `mattermost` exists
- [ ] Restore database if required
- [ ] Verify table/data counts

### Mattermost

- [ ] Restore application files
- [ ] Verify UID/GID 2000:2000
- [ ] Start Mattermost
- [ ] Check container health
- [ ] Check Mattermost logs
- [ ] Test HTTP endpoint
- [ ] Test `/api/v4/system/ping`
- [ ] Test administrator login

### Nginx / HTTPS

- [ ] Restore Nginx configuration
- [ ] Restore TLS certificate configuration
- [ ] Run `nginx -t`
- [ ] Restart Nginx
- [ ] Test HTTPS
- [ ] Test WebSocket / realtime

### Monitoring

- [ ] Start Prometheus
- [ ] Start Alertmanager
- [ ] Start Loki
- [ ] Start Grafana Alloy
- [ ] Start cAdvisor
- [ ] Verify Grafana
- [ ] Verify Prometheus targets
- [ ] Verify Loki logs
- [ ] Verify Alertmanager
- [ ] Verify Mattermost alert delivery

### Final Validation

- [ ] `docker compose ps` shows expected services running
- [ ] PostgreSQL accepts connections
- [ ] Mattermost is healthy
- [ ] HTTPS returns HTTP 200
- [ ] WebSocket returns HTTP 101 during upgrade
- [ ] Users can log in
- [ ] Teams and channels are present
- [ ] Existing posts are present
- [ ] File access works
- [ ] Monitoring is operational
- [ ] Alerts are operational

## 22. Important Recovery Notes

1. Never delete the production PostgreSQL volume before confirming that a verified database backup exists.

2. Never overwrite production Mattermost files with an unverified archive.

3. Always validate SHA-256 checksums before restoring backup archives.

4. The PostgreSQL logical backup is the primary database recovery artifact. The PostgreSQL Docker volume is not the primary backup.

5. Mattermost application files must retain the expected UID/GID ownership when restored.

6. The real Alertmanager Mattermost webhook URL must remain outside GitHub and should be recreated from a secure secret source during recovery.

7. Monitoring storage is separate from the Mattermost application backup and may require a separate recovery procedure if historical monitoring data is needed.

8. System-level Prometheus on port 9090 and Node Exporter on port 9100 are separate from the project Docker monitoring stack and must not be accidentally removed during Mattermost recovery.

9. Nginx and TLS configuration are host-level infrastructure and are not included in the Mattermost application backup archive.

10. A successful recovery requires application, database, HTTPS, WebSocket, and monitoring validation rather than only confirming that the Docker containers are running.
