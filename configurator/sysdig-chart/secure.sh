#!/bin/bash

DIR="$(cd "$(dirname "$0")"; pwd -P)"
source "$DIR/shared-values.sh"

set -euo pipefail

#Important framework functions.
. "$TEMPLATE_DIR/framework.sh"

broadcast "green" "Deploying AnchoreCore"
kubectl apply -f /manifests/generated/anchore-core.yaml
wait_for_pods 10

broadcast "green" "Deploying AncoreWorker"
kubectl apply -f /manifests/generated/anchore-worker.yaml
wait_for_pods 10

broadcast "green" "Deploying Scanning"
kubectl apply -f /manifests/generated/scanning.yaml
wait_for_pods 10
