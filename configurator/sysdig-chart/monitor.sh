#!/bin/ash
set -euo pipefail

#Important framework functions.
. /sysdig-chart/framework.sh

STORAGE_CLASS_NAME=$(cat ${TEMPLATE_DIR}/values.yaml | yq .storageClassName | tr -d '"')
#Create config
if python /sysdig-chart/check_storageclass.py ${STORAGE_CLASS_NAME}; then
  broadcast 'g' "StorageClass exits"
else
  broadcast 'g' "Creating StorageClass"
  kubectl apply -f /manifests/generated/storage-class.yaml
fi

#Create config
broadcast 'g' "Creating common-config"
kubectl apply -f /manifests/generated/common-config.yaml

#Initialize infra pods
broadcast 'g' "Init infra"
kubectl apply -f /manifests/generated/infra.yaml

broadcast 'r' "Waiting for Pods To Come Up"
wait_for_pods 10

#Starting Stateless Deployment
broadcast 'g' "Deploying Backend Components"
kubectl apply -f /manifests/generated/api.yaml
wait_for_pods 10

#Deploy Rest of Backend
kubectl apply -f /manifests/generated/collector-worker.yaml

#Sleep again
broadcast 'r' "Waiting for Pods to come up"
wait_for_pods 10

broadcast 'g' "Creating Ingress Controller"
kubectl apply -f /manifests/generated/ingress.yaml
wait_for_pods 10
