## 1. Set Environment Variables
export GCP_PROJECT=barcelona-439511
export CLUSTER_NAME=cluster1
export CLUSTER_ZONE=us-central1-c
export MODEL=stock-model
export VM_NAME=airflow-vm
export VM_ZONE=us-central1-c
export NETWORK_NAME=etl-network
export BUCKET_NAME=ml-pipeline-ms
export AIRFLOW_USER=airflow
export AIRFLOW_PASSWORD=airflow
export CREDENTIALS_PATH=/home/isamu/Downloads/gcp-key.json
export DATASET_ID=new_york_taxi_trips
export ACCOUNTNAME=airflow-service-account
export NAMESPACE=airflow

## 2. Download and Install Google Cloud SDK
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

sudo apt-get update && sudo apt-get install google-cloud-cli
sudo apt-get install google-cloud-cli-gke-gcloud-auth-plugin

gcloud auth login
gcloud config set account marcsopranzi@gmail.com
gcloud config set project ${GCP_PROJECT}
gcloud auth application-default set-quota-project ${GCP_PROJECT}
gcloud services enable container.googleapis.com artifactregistry.googleapis.com compute.googleapis.com storage.googleapis.com

## Network
gcloud compute networks create ${NETWORK_NAME} --subnet-mode=custom
gcloud compute networks subnets create ${NETWORK_NAME}-subnet \
  --network=${NETWORK_NAME} \
  --region=${CLUSTER_ZONE%-*} \
  --range=10.0.0.0/24

# Get the current IP address of the user to limit the access to the Airflow UI and SSH
MY_IP_ADDRESS=$(curl -s https://ipinfo.io/ip)

# Create a firewall rule to allow access to Airflow UI from the current IP only
gcloud compute firewall-rules create allow-airflow-ui \
  --network=${NETWORK_NAME} \
  --allow tcp:8080 \
  --source-ranges $MY_IP_ADDRESS/32 \
  --target-tags airflow-vm

# Create a firewall rule to allow SSH from the current IP only
gcloud compute firewall-rules create allow-ssh \
  --allow tcp:22 \
  --network=${NETWORK_NAME} \
  --source-ranges $MY_IP_ADDRESS/32 \
  --target-tags airflow-vm

## Storage
gsutil mb -p ${GCP_PROJECT} gs://${BUCKET_NAME}
gsutil cp gcp/airflow/dags/k8s.py gs://${BUCKET_NAME}/ 
gsutil cp gcp/airflow/dags/dummy.py gs://${BUCKET_NAME}/

## Permissions
gcloud iam service-accounts create ${ACCOUNTNAME} --display-name "Airflow account"
gcloud iam service-accounts keys create ${CREDENTIALS_PATH} \
    --iam-account ${ACCOUNTNAME}@${GCP_PROJECT}.iam.gserviceaccount.com

## Roles
gcloud projects add-iam-policy-binding ${GCP_PROJECT} \
    --member "serviceAccount:${ACCOUNTNAME}@${GCP_PROJECT}.iam.gserviceaccount.com" \
    --role "roles/container.admin"

gcloud projects add-iam-policy-binding ${GCP_PROJECT} \
    --member "serviceAccount:${ACCOUNTNAME}@${GCP_PROJECT}.iam.gserviceaccount.com" \
    --role "roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding ${GCP_PROJECT} \
    --member "serviceAccount:${ACCOUNTNAME}@${GCP_PROJECT}.iam.gserviceaccount.com" \
    --role "roles/storage.admin"gsutil mb -p ${GCP_PROJECT} gs://${BUCKET_NAME}

gcloud projects add-iam-policy-binding ${GCP_PROJECT} \
  --member "serviceAccount:${ACCOUNTNAME}@${GCP_PROJECT}.iam.gserviceaccount.com" \
  --role "roles/container.admin"

gcloud projects add-iam-policy-binding ${GCP_PROJECT} \
  --member "serviceAccount:${ACCOUNTNAME}@${GCP_PROJECT}.iam.gserviceaccount.com" \
  --role "roles/storage.admin"

gcloud projects add-iam-policy-binding ${GCP_PROJECT} \
  --member "serviceAccount:${ACCOUNTNAME}@${GCP_PROJECT}.iam.gserviceaccount.com" \
  --role "roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding ${GCP_PROJECT} \
    --member "serviceAccount:${ACCOUNTNAME}@${GCP_PROJECT}.iam.gserviceaccount.com" \
    --role "roles/artifactregistry.writer"

gsutil iam ch serviceAccount:${ACCOUNTNAME}@${GCP_PROJECT}.iam.gserviceaccount.com:roles/storage.admin gs://${BUCKET_NAME}



## Kubernetes
gcloud container clusters create ${CLUSTER_NAME} \
  --zone ${CLUSTER_ZONE} \
  --num-nodes=1 \
  --machine-type=e2-small \
  --enable-autoscaling --min-nodes=1 --max-nodes=3 \
  --network ${NETWORK_NAME} \
  --subnetwork ${NETWORK_NAME}-subnet

gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${CLUSTER_ZONE} --project ${GCP_PROJECT}

export KUBECONFIG=$HOME/.kube/config

## Kubernetes Permissions
kubectl create namespace airflow

kubectl create serviceaccount airflow-service-account -n airflow


kubectl create secret generic gcp-key-secret \
    --from-file=key.json=${CREDENTIALS_PATH} \
    --namespace airflow

kubectl create rolebinding airflow-sa-rolebinding \
  --clusterrole=edit \
  --serviceaccount=airflow:airflow-service-account \
  --namespace=airflow


# Save Deployment YAML
cat <<EOF > gcp/deployment_raw.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: raw-data-extraction-job
  namespace: airflow
spec:
  parallelism: 3  # Adjust to the number of parallel Pods you want
  completions: 3  # Total number of successful completions needed
  template:
    metadata:
      labels:
        app: raw-data-extraction
    spec:
      serviceAccountName: ${ACCOUNTNAME}
      restartPolicy: Never
      containers:
      - name: raw-data-extraction
        image: gcr.io/${GCP_PROJECT}/raw:latest
        command: ["python", "raw.py"]
        env:
        - name: GCP_PROJECT
          value: "${GCP_PROJECT}"
        - name: BUCKET_NAME
          value: "${BUCKET_NAME}"
        volumeMounts:
        - name: gcp-key-volume
          mountPath: /var/secrets/google
          readOnly: true
        resources:
          requests:
            memory: "512Mi"  # Minimum amount of memory requested (enough for the workload)
            cpu: "250m"      # Minimum amount of CPU requested (enough for extraction and upload)
          limits:
            memory: "1Gi"    # Maximum amount of memory allowed (to handle peaks)
            cpu: "500m"      # Maximum amount of CPU allowed (for a bit of headroom)
      volumes:
      - name: gcp-key-volume
        secret:
          secretName: gcp-key-secret
EOF

cat <<EOF > gcp/deployment_etl.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-transformation-job
  namespace: airflow
spec:
  parallelism: 3  # Adjust to the number of parallel Pods you want
  completions: 3  # Total number of successful completions needed
  template:
    metadata:
      labels:
        app: data-transformation
    spec:
      serviceAccountName: ${ACCOUNTNAME}
      restartPolicy: Never
      containers:
      - name: data-transformation
        image: gcr.io/${GCP_PROJECT}/etl:latest
        command: ["python", "etl.py"]
        env:
        - name: GCP_PROJECT
          value: "${GCP_PROJECT}"
        - name: BUCKET_NAME
          value: "${BUCKET_NAME}"
        volumeMounts:
        - name: gcp-key-volume
          mountPath: /var/secrets/google
          readOnly: true
        resources:
          requests:
            memory: "512Mi"  # Minimum amount of memory requested (enough for the workload)
            cpu: "250m"      # Minimum amount of CPU requested (enough for extraction and upload)
          limits:
            memory: "1Gi"    # Maximum amount of memory allowed (to handle peaks)
            cpu: "500m"      # Maximum amount of CPU allowed (for a bit of headroom)

      volumes:
      - name: gcp-key-volume
        secret:
          secretName: gcp-key-secret
EOF

# Save Pod Watcher Role YAML
cat <<EOF > gcp/pod-watcher-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: airflow
  name: pod-watcher
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
EOF

# Save Pod Watcher Role Binding YAML
cat <<EOF > gcp/pod-watcher-rolebinding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-watcher-binding
  namespace: airflow
subjects:
- kind: ServiceAccount
  name: ${ACCOUNTNAME}
  namespace: airflow
roleRef:
  kind: Role
  name: pod-watcher
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl apply -f gcp/deployment_raw.yaml
kubectl apply -f gcp/deployment_etl.yaml

kubectl apply -f gcp/pod-watcher-role.yaml
kubectl apply -f gcp/pod-watcher-rolebinding.yaml

# Test
# gcloud config get-value account
# gcloud projects list --filter="${GCP_PROJECT}"
# gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${CLUSTER_ZONE} --project ${GCP_PROJECT}


# kubectl delete job data-transformation-job -n airflow
# kubectl apply -f gcp/deployment_etl.yaml


# kubectl get pods -n airflow
# kubectl logs raw-data-extraction-job -n airflow

# kubectl logs data-transformation-job-ckjl9 -n airflow


## Push Docker Image
docker build -t gcr.io/${GCP_PROJECT}/raw:latest -f Dockerfile.raw .
docker push gcr.io/${GCP_PROJECT}/raw:latest

docker build -t gcr.io/${GCP_PROJECT}/etl:latest -f Dockerfile.etl .
docker push gcr.io/${GCP_PROJECT}/etl:latest

## Prepare the VM Setup Script
rm gcp/vm.sh

cat <<EOF > gcp/vm.sh
#!/bin/bash

export GCP_PROJECT=${GCP_PROJECT}
export BUCKET_NAME=${BUCKET_NAME}
export CLUSTER_NAME=${CLUSTER_NAME}
export CLUSTER_ZONE=${CLUSTER_ZONE}
export GOOGLE_APPLICATION_CREDENTIALS=/home/airflow/gcp-key.json

# Debugging
exec > >(tee /var/log/startup-script.log | logger -t startup-script) 2>&1
set -x

sudo useradd -m -s /bin/bash airflow
echo "airflow:airflow" | sudo chpasswd
echo "airflow ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/airflow

sudo cp /var/gcp-key.json /home/airflow/gcp-key.json
sudo chown airflow:airflow /home/airflow/gcp-key.json

# This has be run as root
sudo mkdir -p /mnt/airflow/airflow_dags
sudo chown airflow:airflow /mnt/airflow/airflow_dags

sudo -i -u airflow

echo "deb http://packages.cloud.google.com/apt gcsfuse-bullseye main" | sudo tee /etc/apt/sources.list.d/gcsfuse.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

sudo apt-get update

sudo apt-get install -y python3=3.9.* python3-pip=20.3.* python3-venv=3.9.* curl apt-transport-https gcsfuse \
    libpq-dev=13.* gcc=4:10.* g++=4:10.* make=4.*

sudo apt-get install google-cloud-cli-gke-gcloud-auth-plugin

sudo apt-get install kubectla

# # Set up GCSFUSE to mount GCS bucket for DAGs
gcsfuse --implicit-dirs ${BUCKET_NAME} /mnt/airflow/airflow_dags

ls /mnt/airflow/airflow_dags

gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${CLUSTER_ZONE} --project ${GCP_PROJECT}
export KUBECONFIG=/home/airflow/.kube/config

# # Install airflow
python3 -m venv airflow_venv
source airflow_venv/bin/activate

sudo mkdir -p /mnt/airflow/logs
sudo mkdir -p /mnt/airflow/plugins
sudo chown -R 50000:50000 /mnt/airflow/logs /mnt/airflow/plugins 


# pip install --upgrade pip
AIRFLOW_VERSION=2.5.0
CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-\${AIRFLOW_VERSION}/constraints-3.8.txt"
pip install "apache-airflow==\${AIRFLOW_VERSION}" --constraint "\${CONSTRAINT_URL}"
pip install "apache-airflow-providers-cncf-kubernetes" --constraint "\${CONSTRAINT_URL}"
pip install "apache-airflow-providers-google" --constraint "\${CONSTRAINT_URL}"

airflow db init

sed -i "s|^load_examples.*|load_examples = False|" /home/airflow/airflow/airflow.cfg
sed -i "s|^dags_folder.*|dags_folder = /mnt/airflow/airflow_dags|" /home/airflow/airflow/airflow.cfg

cat <<EOF_CFG | sudo tee -a /home/airflow/airflow/airflow.cfg

[kubernetes]
namespace = airflow
worker_container_repository = gcr.io/${GCP_PROJECT}/
worker_container_tag = latest
delete_worker_pods = True
EOF_CFG

airflow users create \
    --username airflow \
    --firstname Admin \
    --lastname User \
    --role Admin \
    --email admin@example2.com \
    --password airflow

airflow scheduler -D
airflow webserver -p 8080 -D

EOF

## Create the Airflow VM
gcloud compute instances create ${VM_NAME} \
  --zone=${VM_ZONE} \
  --machine-type=e2-small \
  --network=${NETWORK_NAME} \
  --subnet=${NETWORK_NAME}-subnet \
  --tags=airflow-vm \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --metadata-from-file startup-script=gcp/vm.sh \
  --metadata "key-file-path=${CREDENTIALS_PATH}"

# gcloud compute ssh ${VM_NAME} --zone=${VM_ZONE}

# sudo pkill -f "airflow scheduler"
# sudo pkill -f "airflow webserver"
