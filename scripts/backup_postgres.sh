#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${PROJECT_DIR}/backups"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

cd "${PROJECT_DIR}"
mkdir -p "${BACKUP_DIR}"

set -a
source .env
set +a

BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"

if ! [[ "${BACKUP_RETENTION_DAYS}" =~ ^[0-9]+$ ]]; then
  echo "BACKUP_RETENTION_DAYS must be a non-negative integer." >&2
  exit 1
fi

docker compose exec -T postgres pg_dump \
  -U "${POSTGRES_USER}" \
  -d "${POSTGRES_DB}" \
  -Fc \
  > "${BACKUP_DIR}/airflow_metadata_${TIMESTAMP}.dump"

find "${BACKUP_DIR}" -name "airflow_metadata_*.dump" -type f -mtime +"${BACKUP_RETENTION_DAYS}" -delete

echo "Backup created: ${BACKUP_DIR}/airflow_metadata_${TIMESTAMP}.dump"
echo "Retention: ${BACKUP_RETENTION_DAYS} days"
