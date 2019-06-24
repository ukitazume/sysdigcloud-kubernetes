#!/bin/bash
set -euo pipefail

#Important framework functions.
. /sysdig-chart/framework.sh

if [[ "$(yq -r .storageClassProvisioner /sysdig-chart/values.yaml)" == "hostPath" ]]; then
  broadcast 'g' "hostPath mode, skipping StorageClass"
else
  STORAGE_CLASS_NAME=$(yq -r .storageClassName /sysdig-chart/values.yaml)
  #Create config
  STORAGE_CLASS="$(kubectl get storageclass "${STORAGE_CLASS_NAME}" 2> /dev/null || /bin/true)"
  if [[ $STORAGE_CLASS != "" ]]; then
    broadcast 'g' "StorageClass ${STORAGE_CLASS_NAME} exits. Skipping storageClass creation..."
  else
    broadcast 'g' "Creating StorageClass"
    kubectl apply -f /manifests/generated/storage-class.yaml
  fi
fi

#Create config
broadcast 'g' "Creating common-config"
kubectl apply -f /manifests/generated/common-config.yaml

DEPLOYMENT=$(yq -r .deployment /sysdig-chart/values.yaml)
if [[ ${DEPLOYMENT} == "openshift" ]];
then
  broadcast 'g' "Skippping Ingress deploy for openshift..."
else
  broadcast 'g' "Creating Ingress Controller"
  kubectl apply -f /manifests/generated/ingress.yaml
  wait_for_pods 10
fi

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

