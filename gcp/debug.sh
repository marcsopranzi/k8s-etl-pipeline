

## 2. Download and Install Google Cloud SDK

curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

sudo apt-get update && sudo apt-get install google-cloud-cli

sudo apt-get install google-cloud-cli-gke-gcloud-auth-plugin

## 3. Authenticate and Set Project Configuration
gcloud auth login
gcloud config set account marcsopranzi@gmail.com
gcloud config set project ${GCP_PROJECT}
gcloud auth application-default set-quota-project ${GCP_PROJECT}
gcloud services enable container.googleapis.com artifactregistry.googleapis.com compute.googleapis.com storage.googleapis.com
gcloud auth configure-docker
gcloud auth configure-docker gcr.io


gcloud compute ssh ${VM_NAME} --zone=${VM_ZONE}


sudo -i -u airflow


stat /var/log/startup-script.log
tail  /var/log/startup-script.log

source airflow_venv/bin/activate

sudo netstat -tuln | grep 8080

sudo ss -tuln | grep 8080

if airflow db check; then
    echo "Airflow database initialized successfully."
else
    echo "Airflow database initialization failed."
fi

cat ~/.bashrc

pip3 show apache-airflow

sudo pkill -f "airflow scheduler"
sudo pkill -f "airflow webserver"
airflow webserver --port 8080 & airflow scheduler
-->

kubectl get pods -n airflow

kubectl describe pod python-script-deployment-59c658f646-7qw9z -n airflow

kubectl delete job python-script-job  -n airflow

kubectl logs python-script-deployment-59c658f646-7qw9z -n airflow

kubectl describe nodes gke-cluster1-default-pool-d6aaafb5-x042  -n airflow


kubectl describe pod python-script-job-1f91e79af2ac4792b63b29baa08ff26e -n airflow


 -->



# Set Environment Variables
export GCP_PROJECT=barcelona-439511
export CLUSTER_NAME=cluster1
export CLUSTER_ZONE=us-central1-c
export VM_NAME=airflow-vm
export VM_ZONE=us-central1-c
export NETWORK_NAME=etl-network
export BUCKET_NAME=ml-pipeline-ms
export GSA=airflow-common
export CREDENTIALS_PATH=/home/isamu/Downloads/gcp-key.json


# Delete Kubernetes Cluster
gcloud container clusters delete ${CLUSTER_NAME} --zone ${CLUSTER_ZONE} --quiet

# Delete Compute Engine VM
gcloud compute instances delete ${VM_NAME} --zone ${VM_ZONE} --quiet

# Delete Firewall Rules
gcloud compute firewall-rules delete allow-airflow-ui --quiet
gcloud compute firewall-rules delete allow-ssh --quiet

# Delete Network and Subnet
gcloud compute networks subnets delete ${NETWORK_NAME}-subnet --region=${CLUSTER_ZONE%-*} --quiet
gcloud compute networks delete ${NETWORK_NAME} --quiet



# Remove IAM Policy Bindings
gcloud projects remove-iam-policy-binding ${GCP_PROJECT} \
    --member "serviceAccount:${GSA}@${GCP_PROJECT}.iam.gserviceaccount.com" \
    --role "roles/container.admin"

gcloud projects remove-iam-policy-binding ${GCP_PROJECT} \
    --member "serviceAccount:${GSA}@${GCP_PROJECT}.iam.gserviceaccount.com" \
    --role "roles/iam.serviceAccountUser"

gcloud projects remove-iam-policy-binding ${GCP_PROJECT} \
    --member "serviceAccount:${GSA}@${GCP_PROJECT}.iam.gserviceaccount.com" \
    --role "roles/storage.admin"

gcloud projects remove-iam-policy-binding ${GCP_PROJECT} \
    --member "serviceAccount:${GSA}@${GCP_PROJECT}.iam.gserviceaccount.com" \
    --role "roles/artifactregistry.writer"

gsutil iam ch -d serviceAccount:${GSA}@${GCP_PROJECT}.iam.gserviceaccount.com:roles/storage.admin gs://${BUCKET_NAME}

# Delete the Service Account
gcloud iam service-accounts delete ${GSA}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet

gcloud iam service-accounts delete airflow-gsa@${GCP_PROJECT}.iam.gserviceaccount.com --quiet

# Delete the Service Account
gcloud iam service-accounts delete airflow-gsa@${GCP_PROJECT}.iam.gserviceaccount.com --quiet

# Remove the Key File
rm ${CREDENTIALS_PATH}

# Delete Kubernetes Resources
kubectl delete namespace airflow --ignore-not-found
kubectl delete clusterrolebinding pod-watcher-binding --ignore-not-found
kubectl delete -f gcp/deployment.yaml --ignore-not-found
kubectl delete -f gcp/pod-watcher-role.yaml --ignore-not-found
kubectl delete -f gcp/pod-watcher-rolebinding.yaml --ignore-not-found

# Delete GCS Bucket
gsutil rm -r gs://${BUCKET_NAME}



