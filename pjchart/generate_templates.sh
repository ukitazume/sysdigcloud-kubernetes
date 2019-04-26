#!/bin/bash

echo "happy templating!!"

echo "step1: removing exiting manifests"
rm -rf manifests/

echo "step2: creating manifest dirs"
mkdir manifests && mkdir manifests/final

echo "step1: running through helm template engine"
helm template --values values.yaml --output-dir manifests/ .

echo "step2: generate commong files"
kustomize build manifests/pjchart/templates/common-config/ > manifests/final/common-config.yaml

echo "step3: data-stores cassandra"
kustomize build manifests//pjchart/templates/data-stores/overlays/cassandra/small/ > manifests/final/cassandra.yaml


#echo "step 5: generate postgres yaml"
#kustomize build manifests/pjchart/templates/infra/postgres/ > manifests/final/postgres.yaml

#echo "step k: generating api yaml"
#kustomize build manifests/pjchart/templates/apps/overlays/api/small > manifests/final/api.yaml

#echo "step k: generating collector yaml"
#kustomize build manifests/pjchart/templates/apps/overlays/collector/small > manifests/final/collector.yaml

#echo "step x: genrating secure config yaml"
#kustomize build manifests/pjchart/templates/apps/secure/ > manifests/final/secure.yaml
