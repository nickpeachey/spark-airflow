from airflow import DAG
from airflow.utils.dates import days_ago
from airflow.operators.dummy import DummyOperator

# Define the DAG
with DAG(
    dag_id='my_first_dag',
    schedule_interval='@daily',
    start_date=days_ago(1),
    catchup=False,
) as dag:

    # Define tasks
    start_task = DummyOperator(
        task_id='start_task'
    )

    end_task = DummyOperator(
        task_id='end_task'
    )

    # Set task dependencies
    start_task >> end_task
