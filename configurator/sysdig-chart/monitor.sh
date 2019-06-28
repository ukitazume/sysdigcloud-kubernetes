#!/bin/bash

DIR="$(cd "$(dirname "$0")"; pwd -P)"
source "$DIR/shared-values.sh"

set -euo pipefail

#Important framework functions.
source "$TEMPLATE_DIR/framework.sh"

if [[ "$(yq -r .storageClassProvisioner "$TEMPLATE_DIR/values.yaml")" == "hostPath" ]]; then
  log notice "hostPath mode, skipping StorageClass"
else
  STORAGE_CLASS_NAME=$(yq -r .storageClassName "$TEMPLATE_DIR/values.yaml")
  #Create config
  STORAGE_CLASS="$(kubectl get storageclass "$STORAGE_CLASS_NAME" 2> /dev/null || /bin/true)"
  if [[ "$STORAGE_CLASS" != "" ]]; then
    log notice "StorageClass $STORAGE_CLASS_NAME exits. Skipping storageClass creation..."
  else
    log notice "Creating StorageClass"
    kubectl apply -f /manifests/generated/storage-class.yaml
  fi
fi

#Create config
log notice "Creating common-config"
kubectl apply -f /manifests/generated/common-config.yaml

SECRET_NAME="ca-certs"
if kubectl -n "$K8S_NAMESPACE" get secret ${SECRET_NAME}; then
  log info "secret '${SECRET_NAME}' already exists. Skipping elasticsearch secret creation"
else
  log info "installing elasticsearch tls certs"
  kubectl -n "$K8S_NAMESPACE" create secret generic ${SECRET_NAME} --from-file="${MANIFESTS}/elasticsearch-tls-certs"
fi

DEPLOYMENT=$(yq -r .deployment "$TEMPLATE_DIR/values.yaml")
if [[ "${DEPLOYMENT}" == "openshift" ]];
then
  log notice "Skippping Ingress deploy for openshift..."
else
  log notice "Creating Ingress Controller"
  kubectl apply -f /manifests/generated/ingress.yaml
  wait_for_pods 10
fi

function delete_resource_if_exists(){
  local resourceType=$1
  local resourceName=$2
  IS_EXISTS="$(kubectl -n "$K8S_NAMESPACE" get "$resourceType" "$resourceName" 2> /dev/null || /bin/true)"
  if [[ "$IS_EXISTS" != "" ]]; then
    kubectl -n "$K8S_NAMESPACE" delete "$resourceType" "$resourceName"
    log error "Deleting $resourceType $resourceName : redisHa=$IS_REDIS_HA config..."
  fi
}

#Redis safety check
IS_REDIS_HA=$(yq .sysdig.redisHa /sysdig-chart/values.yaml)
if [[ "$IS_REDIS_HA" == "true" ]]; then
  #check Redis is running - if yes uninstall redis
  delete_resource_if_exists deployment sysdigcloud-redis
else
  #check if redis ha is running -if yes uninstall redis-ha
  delete_resource_if_exists statefulset redis-primary
  delete_resource_if_exists statefulset redis-secondary
  delete_resource_if_exists statefulset redis-sentinel
fi
#Initialize infra pods
log notice "Init infra"
kubectl apply -f /manifests/generated/infra.yaml

log error "Waiting for Pods To Come Up"
wait_for_pods 10

#Starting Stateless Deployment
log notice "Deploying Backend Components"
kubectl apply -f /manifests/generated/api.yaml
wait_for_pods 10

#Deploy Rest of Backend
kubectl apply -f /manifests/generated/collector-worker.yaml

#Sleep again
log error "Waiting for Pods to come up"
wait_for_pods 10

