#!/bin/ash
set -euo pipefail

#Important framework functions.
. /sysdig-chart/framework.sh
NAMESPACE=$(yq -r .namespace /sysdig-chart/values.yaml)

if [[ "$(yq -r .storageClassProvisioner /sysdig-chart/values.yaml)" == "hostPath" ]]; then
  broadcast "green" "hostPath mode, skipping StorageClass"
else
  STORAGE_CLASS_NAME=$(yq -r .storageClassName /sysdig-chart/values.yaml)
  #Create config
  STORAGE_CLASS="$(kubectl get storageclass ${STORAGE_CLASS_NAME} 2> /dev/null || /bin/true)"
  if [[ "$STORAGE_CLASS" != "" ]]; then
    broadcast "green" "StorageClass ${STORAGE_CLASS_NAME} exits. Skipping storageClass creation..."
  else
    broadcast "green" "Creating StorageClass"
    kubectl apply -f /manifests/generated/storage-class.yaml
  fi
fi

#Create config
broadcast "green" "Creating common-config"
kubectl apply -f /manifests/generated/common-config.yaml

DEPLOYMENT=$(yq -r .deployment /sysdig-chart/values.yaml)
if [[ ${DEPLOYMENT} == "openshift" ]];
then
  broadcast "green" "Skippping Ingress deploy for openshift..."
else
  broadcast "green" "Creating Ingress Controller"
  kubectl apply -f /manifests/generated/ingress.yaml
  wait_for_pods 10
fi

function delete_resource_if_exists(){
  local resourceType=$1
  local resourceName=$2
  IS_EXISTS="$(kubectl -n $NAMESPACE get $resourceType $resourceName 2> /dev/null || /bin/true)"
  if [[ "$IS_EXISTS" != "" ]]; then
    kubectl -n $NAMESPACE delete $resourceType $resourceName
    broadcast "red" "Deleting $resourceType $resourceName : redisHa=$IS_REDIS_HA config..."
  fi
}

#Redis safety check
IS_REDIS_HA=$(yq .sysdig.redisHa /sysdig-chart/values.yaml)
if [[ $IS_REDIS_HA == "true" ]]; then
  #check Redis is running - if yes uninstall redis
  delete_resource_if_exists deployment sysdigcloud-redis
else
  #check if redis ha is running -if yes uninstall redis-ha
  delete_resource_if_exists statefulset redis-primary
  delete_resource_if_exists statefulset redis-secondary
  delete_resource_if_exists statefulset redis-sentinel
fi
#Initialize infra pods
broadcast "green" "Init infra"
kubectl apply -f /manifests/generated/infra.yaml

broadcast "red" "Waiting for Pods To Come Up"
wait_for_pods 10

#Starting Stateless Deployment
broadcast "green" "Deploying Backend Components"
kubectl apply -f /manifests/generated/api.yaml
wait_for_pods 10

#Deploy Rest of Backend
kubectl apply -f /manifests/generated/collector-worker.yaml

#Sleep again
broadcast "red" "Waiting for Pods to come up"
wait_for_pods 10

