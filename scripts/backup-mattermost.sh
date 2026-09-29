#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_ROOT="${PROJECT_DIR}/backups"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"

POSTGRES_CONTAINER="mattermost-postgres"
POSTGRES_USER="mmuser"
POSTGRES_DB="mattermost"

echo "========================================"
echo "Mattermost Backup"
echo "========================================"
echo "Project : ${PROJECT_DIR}"
echo "Backup  : ${BACKUP_DIR}"
echo

mkdir -p "${BACKUP_DIR}"

echo "[1/7] Creating PostgreSQL backup..."

docker exec "${POSTGRES_CONTAINER}" \
    pg_dump \
    -U "${POSTGRES_USER}" \
    -d "${POSTGRES_DB}" \
    -Fc \
    > "${BACKUP_DIR}/mattermost-db.dump"

echo "PostgreSQL backup created."

echo
echo "[2/7] Creating Mattermost file backup..."

cd "${PROJECT_DIR}"

sudo tar \
    --numeric-owner \
    -czf "${BACKUP_DIR}/mattermost-files.tar.gz" \
    config \
    data \
    plugins \
    client-plugins \
    bleve-indexes

sudo chown "$(id -u):$(id -g)" \
    "${BACKUP_DIR}/mattermost-files.tar.gz"

echo "Mattermost file backup created."

echo
echo "[3/7] Generating SHA-256 checksums..."

cd "${BACKUP_DIR}"

sha256sum \
    mattermost-db.dump \
    mattermost-files.tar.gz \
    > SHA256SUMS

echo "Checksums created."

echo
echo "[4/7] Validating PostgreSQL backup..."

docker cp \
    "${BACKUP_DIR}/mattermost-db.dump" \
    "${POSTGRES_CONTAINER}:/tmp/mattermost-db-backup-validation.dump"

docker exec "${POSTGRES_CONTAINER}" \
    pg_restore \
    -l /tmp/mattermost-db-backup-validation.dump \
    > /dev/null

docker exec "${POSTGRES_CONTAINER}" \
    rm -f /tmp/mattermost-db-backup-validation.dump

echo "PostgreSQL backup validation passed."

echo
echo "[5/7] Validating Mattermost file archive..."

gzip -t "${BACKUP_DIR}/mattermost-files.tar.gz"

echo "Mattermost file archive validation passed."

echo
echo "[6/7] Validating SHA-256 checksums..."

sha256sum -c SHA256SUMS

echo "SHA-256 validation passed."

echo
echo "[7/7] Creating backup manifest..."

POSTGRES_VERSION="$(
    docker exec "${POSTGRES_CONTAINER}" \
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
    -Atc "SELECT version();" \
    | head -1
)"

DATABASE_SIZE="$(
    docker exec "${POSTGRES_CONTAINER}" \
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
    -Atc "SELECT pg_size_pretty(pg_database_size('${POSTGRES_DB}'));"
)"

DB_BACKUP_SIZE="$(du -h mattermost-db.dump | cut -f1)"
FILES_BACKUP_SIZE="$(du -h mattermost-files.tar.gz | cut -f1)"

cat > backup-manifest.txt <<MANIFEST
Mattermost Backup Manifest
==========================

Backup Date:
${TIMESTAMP}

Application:
Mattermost Team Edition

Database:
PostgreSQL

Database Name:
${POSTGRES_DB}

Database User:
${POSTGRES_USER}

PostgreSQL Container:
${POSTGRES_CONTAINER}

PostgreSQL Version:
${POSTGRES_VERSION}

Database Size:
${DATABASE_SIZE}

Backup Components:
- PostgreSQL logical database dump
- Mattermost config
- Mattermost data
- Mattermost plugins
- Mattermost client plugins
- Mattermost Bleve indexes

Database Backup:
mattermost-db.dump

Database Backup Size:
${DB_BACKUP_SIZE}

Mattermost Files Backup:
mattermost-files.tar.gz

Mattermost Files Backup Size:
${FILES_BACKUP_SIZE}

Checksum File:
SHA256SUMS

Mattermost File Ownership:
UID/GID 2000:2000

Validation:
- PostgreSQL archive validated with pg_restore
- Mattermost tar archive validated with gzip
- SHA-256 verification passed

Notes:
The PostgreSQL Docker volume is not used as the primary
database backup. The portable pg_dump custom-format archive
is the database restore source.

Runtime logs are not included in the application backup.
Monitoring data volumes are separate from this Mattermost
application backup.
MANIFEST

echo
echo "========================================"
echo "BACKUP COMPLETED SUCCESSFULLY"
echo "========================================"
echo
echo "Backup location:"
echo "${BACKUP_DIR}"
echo
echo "Backup contents:"
ls -lh "${BACKUP_DIR}"

echo
