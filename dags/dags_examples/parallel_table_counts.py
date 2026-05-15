from __future__ import annotations

import time
from datetime import timedelta

import pendulum
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.providers.standard.operators.empty import EmptyOperator
from airflow.providers.standard.operators.python import PythonOperator
from airflow.sdk import DAG

CONN_ID = "local_toy_postgres"


def count_table_rows(table_name: str, sleep_seconds: int) -> None:
    print(f"Sleeping for {sleep_seconds} seconds before counting {table_name}.")
    time.sleep(sleep_seconds)

    hook = PostgresHook(postgres_conn_id=CONN_ID)
    row_count = hook.get_first(f"select count(*) from {table_name};")[0]
    print(f"{table_name} row count: {row_count}")


with DAG(
    dag_id="parallel_table_counts",
    description="Run independent row count tasks in parallel against local_toy_postgres.",
    schedule=None,
    start_date=pendulum.datetime(2026, 5, 15, tz="Europe/Moscow"),
    catchup=False,
    max_active_runs=1,
    dagrun_timeout=timedelta(minutes=15),
    tags=["test", "postgres", "parallel"],
) as dag:
    start = EmptyOperator(task_id="start")

    count_sale = PythonOperator(
        task_id="count_raw_data_sale",
        python_callable=count_table_rows,
        op_kwargs={
            "table_name": "raw_data.sale",
            "sleep_seconds": 10,
        },
        pool="postgres_pool",
    )

    count_offer = PythonOperator(
        task_id="count_raw_data_offer",
        python_callable=count_table_rows,
        op_kwargs={
            "table_name": "raw_data.offer",
            "sleep_seconds": 30,
        },
        pool="postgres_pool",
    )

    count_restored_sale = PythonOperator(
        task_id="count_shortage_analysis_restored_sale",
        python_callable=count_table_rows,
        op_kwargs={
            "table_name": "shortage_analysis.restored_sale",
            "sleep_seconds": 50,
        },
        pool="postgres_pool",
    )

    count_shapley_values = PythonOperator(
        task_id="count_shortage_analysis_shapley_values",
        python_callable=count_table_rows,
        op_kwargs={
            "table_name": "shortage_analysis.shapley_values",
            "sleep_seconds": 70,
        },
        pool="postgres_pool",
    )

    finish = EmptyOperator(task_id="finish")

    start >> [
        count_sale,
        count_offer,
        count_restored_sale,
        count_shapley_values,
    ] >> finish
