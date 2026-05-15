from __future__ import annotations

from datetime import timedelta

import pendulum
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.providers.standard.operators.python import PythonOperator
from airflow.sdk import DAG

CONN_ID = "local_toy_postgres"


def count_sale_rows():
    hook = PostgresHook(postgres_conn_id=CONN_ID)
    row_count = hook.get_first("select count(*) from raw_data.sale;")[0]
    print(f"raw_data.sale row count: {row_count}")


with DAG(
    dag_id="count_sale_rows",
    description="Count rows in raw_data.sale using local_toy_postgres connection.",
    schedule=None,
    start_date=pendulum.datetime(2026, 5, 15, tz="Europe/Moscow"),
    catchup=False,
    dagrun_timeout=timedelta(minutes=10),
    tags=["test", "postgres"],
) as dag:
    count_rows = PythonOperator(
        task_id="count_sale_rows",
        python_callable=count_sale_rows,
        pool="postgres_pool",
    )
