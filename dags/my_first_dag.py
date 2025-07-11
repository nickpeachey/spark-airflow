from datetime import datetime, timedelta
import json
from airflow import DAG
from airflow.operators.python import PythonOperator

with DAG(
    dag_id="spark_minio_saver_with_localstack",
    start_date=datetime(2023, 1, 1),
    schedule=None,
    catchup=False,
    tags=['spark', 'kubernetes', 'minio', 'connections'],
) as dag:
    
    do_something = PythonOperator(
        task_id='do_something',
        python_callable=lambda: print("Doing something..."),
    )

    do_something