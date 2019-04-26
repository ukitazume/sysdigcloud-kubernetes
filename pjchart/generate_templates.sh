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

echo "step3a: data-stores cassandra"
echo "---" >> manifests/final/infra.yaml
kustomize build manifests//pjchart/templates/data-stores/overlays/cassandra/small/    >> manifests/final/infra.yaml
echo "step3b: data-stores elasticsearch"
echo "---" >> manifests/final/infra.yaml
kustomize build manifests/pjchart/templates/data-stores/overlays/elasticsearch/small/ >> manifests/final/infra.yaml
echo "step3c: data-stores mysql"
echo "---" >> manifests/final/infra.yaml
kustomize build manifests//pjchart/templates/data-stores/overlays/mysql-single/small/ >> manifests/final/infra.yaml
echo "step3d: data-stores postgres"
echo "---" >> manifests/final/infra.yaml
kustomize build manifests//pjchart/templates/data-stores/overlays/postgres/small/     >> manifests/final/infra.yaml
echo "step3e: data-stores redis"
echo "---" >> manifests/final/infra.yaml
kustomize build manifests//pjchart/templates/data-stores/redis-single/                >> manifests/final/infra.yaml

#echo "step 5: generate postgres yaml"
#kustomize build manifests/pjchart/templates/infra/postgres/ > manifests/final/postgres.yaml

#echo "step k: generating api yaml"
#kustomize build manifests/pjchart/templates/apps/overlays/api/small > manifests/final/api.yaml

#echo "step k: generating collector yaml"
#kustomize build manifests/pjchart/templates/apps/overlays/collector/small > manifests/final/collector.yaml

#echo "step x: genrating secure config yaml"
#kustomize build manifests/pjchart/templates/apps/secure/ > manifests/final/secure.yaml
