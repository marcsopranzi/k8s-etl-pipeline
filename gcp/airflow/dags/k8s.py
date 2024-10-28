from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import KubernetesPodOperator
from airflow.utils.dates import days_ago
from datetime import timedelta
from kubernetes.client import models as k8s

# Set environment variables
gcp_project = 'barcelona-439511'
bucket_name = 'ml-pipeline-ms'

# Define default arguments
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': days_ago(1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Initialize DAG
dag = DAG(
    'etl_pipeline',
    default_args=default_args,
    description='A DAG to extract and transform data using Kubernetes pods',
    schedule_interval=timedelta(days=1),
)

# KubernetesPodOperator for RAW extraction
extract_task = KubernetesPodOperator(
    namespace='airflow',
    image=f"gcr.io/{gcp_project}/raw:latest",
    cmds=["python", "raw.py"],
    name="extract_raw_data_job",
    task_id="extract_raw_data",
    get_logs=True,
    dag=dag,
    is_delete_operator_pod=True,
    volume_mounts=[
        k8s.V1VolumeMount(
            name='gcp-key-volume',
            mount_path='/var/secrets/google',
            read_only=True
        )
    ],
    volumes=[
        k8s.V1Volume(
            name='gcp-key-volume',
            secret=k8s.V1SecretVolumeSource(secret_name='gcp-key-secret')
        )
    ],
    env_vars={
        'GOOGLE_APPLICATION_CREDENTIALS': '/var/secrets/google/key.json',
        'BUCKET_NAME': bucket_name
    }
)

# KubernetesPodOperator for ETL transformation
transform_task = KubernetesPodOperator(
    namespace='airflow',
    image=f"gcr.io/{gcp_project}/etl:latest",
    cmds=["python", "etl.py"],
    name="transform_etl_data_job",
    task_id="transform_etl_data",
    get_logs=True,
    dag=dag,
    is_delete_operator_pod=True,
    volume_mounts=[
        k8s.V1VolumeMount(
            name='gcp-key-volume',
            mount_path='/var/secrets/google',
            read_only=True
        )
    ],
    volumes=[
        k8s.V1Volume(
            name='gcp-key-volume',
            secret=k8s.V1SecretVolumeSource(secret_name='gcp-key-secret')
        )
    ],
    env_vars={
        'GOOGLE_APPLICATION_CREDENTIALS': '/var/secrets/google/key.json',
        'BUCKET_NAME': bucket_name
    }
)

# Set task dependencies
extract_task >> transform_task
