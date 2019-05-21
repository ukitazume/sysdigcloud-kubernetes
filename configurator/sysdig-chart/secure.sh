#/bin/bash

#Important framework functions.
. /sysdig-chart/framework.sh

broadcast 'g' "Deploying AnchoreCore"
ka /manifests/generated/anchore-core.yaml
wait_for_pods 10

broadcast 'g' "Deploying AncoreWorker"
ka /manifests/generated/anchore-worker.yaml
wait_for_pods 10

broadcast 'g' "Deploying Scanning"
ka /manifests/generated/scanning.yaml
wait_for_pods 10
