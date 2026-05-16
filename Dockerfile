ARG AIRFLOW_VERSION=3.2.1
ARG PYTHON_VERSION=3.13
FROM apache/airflow:${AIRFLOW_VERSION}

ARG AIRFLOW_VERSION=3.2.1
ARG PYTHON_VERSION=3.13

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER airflow
COPY requirements.txt /requirements.txt
RUN pip install --no-cache-dir \
    --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt" \
    -r /requirements.txt
