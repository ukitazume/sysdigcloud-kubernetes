#!/bin/ash

#Important framework functions.
. /sysdig-chart/framework.sh

#Create config
broadcast 'g' "Creating common-config"
ka /manifests/generated/common-config.yaml

#Initialize infra pods
broadcast 'g' "Init infra"
ka /manifests/generated/infra.yaml

broadcast 'r' "Waiting for Pods To Come Up"
wait_for_pods 10

#Starting Stateless Deployment
broadcast 'g' "Deploying Backend Components"
ka /manifests/generated/api.yaml
wait_for_pods 10

#Deploy Rest of Backend
ka /manifests/generated/collector-worker.yaml

#Sleep again
broadcast 'r' "Waiting for Pods to come up"
wait_for_pods 10

broadcast 'g' "Creating Ingress Controller"
ka /manifests/generated/ingress.yaml
wait_for_pods 10
