# k8s-etl-pipeline

This is a proof-of-concept (POC) for the rapid creation of a scalable ETL (Extract, Transform, Load) data pipeline using Kubernetes, Google Cloud Storage, and related Google Cloud services.

## Overview
The **k8s-etl-pipeline** project demonstrates how to set up an end-to-end data pipeline leveraging Kubernetes, Google Cloud Storage (GCS), Google Kubernetes Engine (GKE), and Apache Airflow. This solution is ideal for scenarios requiring a scalable, cloud-native approach for extracting data, transforming it, and storing it in a data lake or other cloud storage.

The POC deploys two jobs:
1. **Data Extraction Job**: Extracts raw stock market data and stores it in Google Cloud Storage.
2. **Data Transformation Job**: Transforms the raw data and stores the results back to GCS.

## Architecture
The pipeline is built using the following cloud components:

- **Google Kubernetes Engine (GKE)**: To orchestrate containerized workloads.
- **Google Cloud Storage (GCS)**: To store raw and transformed data.
- **Apache Airflow**: To manage and monitor the data pipeline.
- **Google Compute Engine (VM)**: To deploy Airflow and provide access to Airflow UI.
- **Service Accounts and IAM Roles**: To ensure proper permissions for accessing GCP resources.

The pipeline leverages Kubernetes Jobs for executing the data extraction and transformation in a scalable and controlled manner.

## Prerequisites

- **Google Cloud SDK** installed locally.
- A Google Cloud Platform (GCP) account with billing enabled.
- **Docker** installed locally to build images.
- Access to a **GCP service account key**.
- **kubectl** installed to interact with Kubernetes clusters.
- A **Google Cloud Project**.

## Setup Instructions

### Step 1: Set Environment Variables
Export environment variables to configure the deployment, e.g.:
```bash
export GCP_PROJECT=barcelona-439511
export CLUSTER_NAME=cluster1
export CLUSTER_ZONE=us-central1-c
export NETWORK_NAME=etl-network
export BUCKET_NAME=ml-pipeline-ms
export CREDENTIALS_PATH=/home/user/Downloads/gcp-key.json
```

### Step 2: Install Google Cloud SDK and Authenticate
Install Google Cloud SDK and enable necessary services:
```bash
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
sudo apt-get update && sudo apt-get install google-cloud-cli
```

Authenticate and configure your project:
```bash
gcloud auth login
gcloud config set account <YOUR_GCP_EMAIL>
gcloud config set project ${GCP_PROJECT}
gcloud auth application-default set-quota-project ${GCP_PROJECT}
gcloud services enable container.googleapis.com artifactregistry.googleapis.com compute.googleapis.com storage.googleapis.com
```

## Testing and Monitoring

- Check running pods:
  ```bash
  kubectl get pods -n airflow
  ```
- View pod logs:
  ```bash
  kubectl logs <POD_NAME> -n airflow
  ```
- Access the Airflow webserver using SSH:
  ```bash
  gcloud compute ssh ${VM_NAME} --zone=${VM_ZONE}
  ```

## Security Considerations
This is a proof-of-concept, and there are some vulnerabilities:
- **Credentials Handling**: Service account keys are stored locally, which is not recommended for production. Consider using Secret Manager or Workload Identity for secure access.
- **Hardcoded Passwords**: Hardcoded passwords (e.g., Airflow user) should be replaced with secure alternatives, such as environment variables or a secret management solution.
- **Firewall Rules**: The firewall is currently configured to allow access from a specific IP. For a production environment, consider a more robust approach to restrict access.

## Future Improvements
1. **Secrets Management**: Integrate with GCP Secret Manager to manage secrets like GCP credentials and Airflow passwords securely.
2. **Scalability Enhancements**: Use Kubernetes Horizontal Pod Autoscaler for dynamic scaling of Kubernetes jobs based on CPU or memory utilization.
3. **Monitoring**: Set up Google Cloud Monitoring and Logging to track the health and performance of the ETL pipeline and Airflow.
4. **Deployment Automation**: Utilize Terraform or a similar Infrastructure as Code (IaC) tool to automate the setup process.

