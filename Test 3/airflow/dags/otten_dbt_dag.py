import os
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.empty import EmptyOperator
from airflow.operators.bash import BashOperator
from cosmos import (
    DbtTaskGroup,
    ProjectConfig,
    ProfileConfig,
    ExecutionConfig,
    RenderConfig,
    LoadMode
)
from cosmos.profiles import PostgresUserPasswordProfileMapping

# Konfigurasi Path untuk dbt project di environment Airflow
DEFAULT_DBT_ROOT_PATH = os.getenv("DBT_ROOT_PATH", "/opt/airflow/dags/dbt_pipeline")
DBT_EXECUTABLE_PATH = os.getenv("DBT_EXECUTABLE_PATH", "/home/airflow/.local/bin/dbt")

# Konfigurasi Profil dbt menggunakan Airflow Connection (Postgres)
profile_config = ProfileConfig(
    profile_name="otten_coffee_dwh",
    target_name="dev",
    profile_mapping=PostgresUserPasswordProfileMapping(
        conn_id="postgres_default",
        profile_args={"schema": "public"},
    )
)

default_args = {
    "owner": "BI_Engineer",
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="otten_coffee_full_elt_pipeline",
    default_args=default_args,
    start_date=datetime(2024, 1, 1),
    schedule_interval="0 2 * * *",  # Berjalan setiap hari jam 02:00 AM
    catchup=False,
    max_active_runs=1,
    tags=["otten-coffee", "elt", "dbt", "cosmos"],
    description="Full ELT Pipeline: Extract -> Load -> dbt Transform (Staging -> Intermediate -> Mart)",
) as dag:

    # =====================================================================
    # FASE 1: EXTRACT & LOAD (Simulasi Ekstraksi Data Source ke DWH)
    # =====================================================================
    start_pipeline = EmptyOperator(task_id="start_pipeline")

    extract_source_data = BashOperator(
        task_id="extract_postgres_data_via_airbyte",
        bash_command="echo 'Simulating data extraction using Airbyte connector...'; sleep 2"
    )

    load_raw_to_dwh = BashOperator(
        task_id="load_raw_data_to_dwh",
        bash_command="echo 'Loading raw extracted data into PostgreSQL public schema...'; sleep 2"
    )

    # =====================================================================
    # FASE 2: TRANSFORM (Menjalankan dbt models via Cosmos)
    # =====================================================================
    dbt_transformations = DbtTaskGroup(
        group_id="dbt_transformations",
        project_config=ProjectConfig(
            dbt_project_path=DEFAULT_DBT_ROOT_PATH,
        ),
        profile_config=profile_config,
        execution_config=ExecutionConfig(
            dbt_executable_path=DBT_EXECUTABLE_PATH,
        ),
        render_config=RenderConfig(
            load_method=LoadMode.DBT_LS,
            select=["path:models"]
        )
    )

    # =====================================================================
    # FASE 3: DATA QUALITY & NOTIFICATION
    # =====================================================================
    data_quality_check = BashOperator(
        task_id="run_data_quality_tests",
        bash_command="echo 'Running Data Quality constraints...'; sleep 2"
    )

    send_slack_alert = BashOperator(
        task_id="send_slack_notification",
        bash_command="echo 'Sending Slack Alert: Otten Coffee Pipeline Completed Successfully!'",
        trigger_rule="all_success"
    )

    end_pipeline = EmptyOperator(task_id="end_pipeline")

    # =====================================================================
    # MENGATUR URUTAN (DEPENDENCIES) SELURUH PIPELINE
    # =====================================================================
    start_pipeline >> extract_source_data >> load_raw_to_dwh >> dbt_transformations
    dbt_transformations >> data_quality_check >> send_slack_alert >> end_pipeline
