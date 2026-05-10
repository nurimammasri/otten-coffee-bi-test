import os
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.empty import EmptyOperator
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
# Asumsi: folder dbt bernama 'dbt_pipeline' berada di dalam folder dags/
DEFAULT_DBT_ROOT_PATH = os.getenv("DBT_ROOT_PATH", "/opt/airflow/dags/dbt_pipeline")
DBT_EXECUTABLE_PATH = os.getenv("DBT_EXECUTABLE_PATH", "/opt/airflow/dbt_venv/bin/dbt")

# Konfigurasi Profil dbt menggunakan Airflow Connection (Postgres)
# Airflow Connection ID: 'postgres_default' (dapat dikonfigurasi di Airflow UI)
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
    dag_id="otten_coffee_dbt_cosmos_pipeline",
    default_args=default_args,
    start_date=datetime(2024, 1, 1),
    schedule_interval="0 2 * * *",  # Berjalan setiap hari jam 02:00 AM
    catchup=False,
    max_active_runs=1,
    tags=["otten-coffee", "dbt", "cosmos", "pipeline"],
    description="Orchestrating dbt models (Staging -> Intermediate -> Mart) using Astronomer Cosmos",
) as dag:

    # Task awal pipeline
    start_pipeline = EmptyOperator(task_id="start_pipeline")

    # DbtTaskGroup dari Astronomer Cosmos:
    # Cosmos akan membaca project dbt secara otomatis dan memecahnya menjadi task-task individual 
    # (Node per Node / Model per Model) lengkap dengan dependensinya di Airflow UI.
    dbt_transformations = DbtTaskGroup(
        group_id="dbt_transformations",
        project_config=ProjectConfig(
            dbt_project_path=DEFAULT_DBT_ROOT_PATH,
        ),
        profile_config=profile_config,
        execution_config=ExecutionConfig(
            dbt_executable_path=DBT_EXECUTABLE_PATH,
        ),
        # RenderConfig digunakan untuk menampilkan dbt test di Airflow UI secara native
        render_config=RenderConfig(
            load_method=LoadMode.DBT_LS,
            select=["path:models"]
        )
    )

    # Task akhir pipeline
    end_pipeline = EmptyOperator(task_id="end_pipeline")

    # Mendefinisikan urutan eksekusi (Dependencies)
    start_pipeline >> dbt_transformations >> end_pipeline
