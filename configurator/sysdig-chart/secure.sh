#!/bin/bash
set -euo pipefail

#Important framework functions.
. /sysdig-chart/framework.sh

broadcast 'g' "Deploying AnchoreCore"
kubectl apply -f /manifests/generated/anchore-core.yaml
wait_for_pods 10

broadcast 'g' "Deploying AncoreWorker"
kubectl apply -f /manifests/generated/anchore-worker.yaml
wait_for_pods 10

broadcast 'g' "Deploying Scanning"
kubectl apply -f /manifests/generated/scanning.yaml
wait_for_pods 10
