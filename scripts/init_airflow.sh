#!/usr/bin/env bash
set -euo pipefail

airflow db migrate

ensure_pool() {
  local name="$1"
  local slots="$2"
  local description="$3"

  airflow pools set "${name}" "${slots}" "${description}"
}

ensure_user() {
  local username="$1"
  local firstname="$2"
  local lastname="$3"
  local email="$4"
  local password="$5"
  local role="$6"

  if airflow users list --output plain | awk '{print $2}' | grep -Fxq "${username}"; then
    echo "Airflow user '${username}' already exists."
    return
  fi

  airflow users create \
    --username "${username}" \
    --firstname "${firstname}" \
    --lastname "${lastname}" \
    --role "${role}" \
    --email "${email}" \
    --password "${password}"
}

ensure_user \
  "${AIRFLOW_ADMIN_USERNAME}" \
  "${AIRFLOW_ADMIN_FIRSTNAME}" \
  "${AIRFLOW_ADMIN_LASTNAME}" \
  "${AIRFLOW_ADMIN_EMAIL}" \
  "${AIRFLOW_ADMIN_PASSWORD}" \
  "Admin"

ensure_user \
  "${AIRFLOW_DATA_ENGINEER_USERNAME}" \
  "${AIRFLOW_DATA_ENGINEER_FIRSTNAME}" \
  "${AIRFLOW_DATA_ENGINEER_LASTNAME}" \
  "${AIRFLOW_DATA_ENGINEER_EMAIL}" \
  "${AIRFLOW_DATA_ENGINEER_PASSWORD}" \
  "Admin"

ensure_user \
  "${AIRFLOW_ANALYTICS_HEAD_USERNAME}" \
  "${AIRFLOW_ANALYTICS_HEAD_FIRSTNAME}" \
  "${AIRFLOW_ANALYTICS_HEAD_LASTNAME}" \
  "${AIRFLOW_ANALYTICS_HEAD_EMAIL}" \
  "${AIRFLOW_ANALYTICS_HEAD_PASSWORD}" \
  "Admin"

ensure_user \
  "${AIRFLOW_BUSINESS_ANALYTIC_USERNAME}" \
  "${AIRFLOW_BUSINESS_ANALYTIC_FIRSTNAME}" \
  "${AIRFLOW_BUSINESS_ANALYTIC_LASTNAME}" \
  "${AIRFLOW_BUSINESS_ANALYTIC_EMAIL}" \
  "${AIRFLOW_BUSINESS_ANALYTIC_PASSWORD}" \
  "Viewer"

ensure_pool "clickhouse_pool" "2" "Limit concurrent tasks querying ClickHouse."
ensure_pool "postgres_pool" "3" "Limit concurrent tasks querying PostgreSQL."
ensure_pool "oracle_pool" "1" "Limit concurrent tasks querying Oracle."
ensure_pool "external_etl_pool" "1" "Limit external container or SSH-based ETL jobs."
