#!/bin/bash

set -euo pipefail

# Create kind cluster with resource settings
cat <<EOF | kind create cluster --name airflow-cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
            authorization-mode: "AlwaysAllow"
    extraPortMappings:
      - containerPort: 30080
        hostPort: 8080
        protocol: TCP
      - containerPort: 30090
        hostPort: 9090
        protocol: TCP
EOF

# Namespaces
AIRFLOW_NAMESPACE="airflow"
LOCALSTACK_NAMESPACE="localstack"
SPARK_NAMESPACE="spark-operator"


# Create namespaces
kubectl create namespace $AIRFLOW_NAMESPACE || true
kubectl create namespace $LOCALSTACK_NAMESPACE || true
kubectl create namespace $SPARK_NAMESPACE || true


# Add Helm repos

helm repo add --force-update spark-operator https://kubeflow.github.io/spark-operator

helm repo add --force-update apache-airflow https://airflow.apache.org

# helm repo add --force-update minio https://charts.min.io/

helm repo add --force-update localstack https://helm.localstack.cloud

# Install MinIO in standalone mode with resources and no persistence
helm install localstack localstack/localstack \
  --namespace $LOCALSTACK_NAMESPACE \
  --set service.type=ClusterIP \
  --set startServices="s3" \
  --set persistence.enabled=true \
  --set persistence.storageClass="standard" \
  --set persistence.size="10Gi"

# Wait for MinIO pod ready

sleep 15

# Configure mc alias and create airflow-logs bucket if it does not exist
export POD_NAME=$(kubectl get pods --namespace "localstack" -l "app.kubernetes.io/name=localstack,app.kubernetes.io/instance=localstack" -o jsonpath="{.items[0].metadata.name}")
export CONTAINER_PORT=$(kubectl get pod --namespace "localstack" $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")

sleep 20
echo "visit http://127.0.0.1:8080 to use your application"
kubectl --namespace "localstack" port-forward $POD_NAME 4566:$CONTAINER_PORT > localstack-port-forward.log 2>&1 &


aws --endpoint-url=http://localhost:4566 s3 mb s3://airflow-logs
aws --endpoint-url=http://localhost:4566 s3 mb s3://sample-bucket 
aws --endpoint-url=http://localhost:4566 s3 mb s3://datasets 
aws --endpoint-url=http://localhost:4566 s3 mb s3://my-minio-bucket  

echo "Cluster Ip for Localstack is: $(kubectl get svc --namespace localstack localstack -o jsonpath='{.spec.clusterIP}')"

# Install Spark Operator with RBAC enabled
helm upgrade --install spark-operator spark-operator/spark-operator \
  --namespace $SPARK_NAMESPACE \
  --set sparkJobNamespace=$SPARK_NAMESPACE \
  --set webhook.enable=true \
  --set rbac.create=true

# Install Airflow with airflow-values.yaml (make sure to update that file with MinIO credentials)
helm upgrade --install airflow apache-airflow/airflow  --version 1.16.0  \
  --namespace $AIRFLOW_NAMESPACE \
  --values airflow-values-localstack.yaml

echo "✅ All components installed successfully."


kubectl apply -f sparkoperator-rbac.yaml  

kubectl apply -f airflow-rbac.yaml  

kubectl apply -f spark-role-binding.yaml  


kubectl apply -f spark-service-account.yaml  

kubectl apply -f spark-rbac.yaml  