from airflow import DAG
from airflow.operators.dummy import DummyOperator
from datetime import datetime

# Define the default arguments
default_args = {
    'owner': 'airflow',
    'start_date': datetime(2023, 1, 1),
    'retries': 1,
}

# Define the DAG
with DAG(
    'dummy_dag',
    default_args=default_args,
    description='A simple dummy DAG',
    schedule_interval='@daily',
    catchup=False,
) as dag:

    # Define the tasks
    start = DummyOperator(
        task_id='start',
    )

    end = DummyOperator(
        task_id='end',
    )

    # Set the task dependencies
    start >> end
