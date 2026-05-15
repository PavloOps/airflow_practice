#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "${PROJECT_DIR}"

set -a
source .env
set +a

docker compose exec -T postgres psql \
  -U "${POSTGRES_USER}" \
  -d "${POSTGRES_DB}" \
  -v ON_ERROR_STOP=1 \
  --set=superset_user="${SUPERSET_DB_USER}" \
  --set=superset_password="${SUPERSET_DB_PASSWORD}" \
  --set=database_name="${POSTGRES_DB}" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'superset_user', :'superset_password')
WHERE NOT EXISTS (
  SELECT 1 FROM pg_roles WHERE rolname = :'superset_user'
);
\gexec

SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'superset_user', :'superset_password');
\gexec

SELECT format('GRANT CONNECT ON DATABASE %I TO %I', :'database_name', :'superset_user');
\gexec

SELECT format('GRANT USAGE ON SCHEMA public TO %I', :'superset_user');
\gexec

SELECT format('GRANT SELECT ON ALL TABLES IN SCHEMA public TO %I', :'superset_user');
\gexec

SELECT format('GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO %I', :'superset_user');
\gexec

SELECT format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO %I', :'superset_user');
\gexec

SELECT format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO %I', :'superset_user');
\gexec
SQL
