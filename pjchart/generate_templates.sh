#!/bin/bash

echo "happy templating!!"

echo "step1: removing exiting manifests"
rm -rf manifests/

echo "step2: creating manifest dirs"
mkdir manifests && mkdir manifests/final

echo "step1: running through helm template engine"
helm template --values values.yaml --output-dir manifests/ .

echo "step k: generating api yaml"
kustomize build manifests/pjchart/templates/apps/overlays/api/small > manifests/final/api_config.yaml

echo "step k: generating collector yaml"
kustomize build manifests/pjchart/templates/apps/overlays/collector/small > manifests/final/collector_config.yaml

echo "step x: genrating secure config yaml"
kustomize build manifests/pjchart/templates/apps/anchor/ > manifests/final/secure_config.yaml
