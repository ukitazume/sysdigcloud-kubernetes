#!/bin/bash

echo "happy templating!!"

echo "step1: removing exiting manifests"
rm -rf manifests/

echo "step2: creating manifest dirs"
mkdir manifests && mkdir manifests/final

echo "step3: creating secret file - if it does not exist"
SECRET_FILE=secrets.yaml
if [ -f "$SECRET_FILE" ]; then
    echo "$SECRET_FILE exists"
else
    echo "Secret file does not exist. Creating Secretfile"
    helm template -x templates/secrets.yaml secrets > secrets.yaml
fi

echo "step4: running through helm template engine"
helm template -f values.yaml -f secrets.yaml --output-dir manifests/ .

echo "step5: generate commong files"
kustomize build manifests/pjchart/templates/overlays/common-config/small/ > manifests/final/common-config.yaml

echo "step6:  Generating data-stores"
echo "step6a: data-stores cassandra"
echo "---" >> manifests/final/infra.yaml
kustomize build manifests//pjchart/templates/data-stores/overlays/cassandra/small/    >> manifests/final/infra.yaml
echo "step6b: data-stores elasticsearch"
echo "---" >> manifests/final/infra.yaml
kustomize build manifests/pjchart/templates/data-stores/overlays/elasticsearch/small/ >> manifests/final/infra.yaml
echo "step6c: data-stores mysql"
echo "---" >> manifests/final/infra.yaml
kustomize build manifests//pjchart/templates/data-stores/overlays/mysql-single/small/ >> manifests/final/infra.yaml
echo "step6d: data-stores postgres"
echo "---" >> manifests/final/infra.yaml
kustomize build manifests//pjchart/templates/data-stores/overlays/postgres/small/     >> manifests/final/infra.yaml
echo "step6e: data-stores redis"
echo "---" >> manifests/final/infra.yaml
kustomize build manifests//pjchart/templates/data-stores/redis-single/                >> manifests/final/infra.yaml

echo "step 7: Generating monitor"
echo "step 7a: generate monitor-api yamls"
kustomize build manifests//pjchart/templates/sysdig-cloud/overlays/api/small/              >  manifests/final/api.yaml

echo "step 7b: generate monitor-collectorworker yamls"
kustomize build manifests//pjchart/templates/sysdig-cloud/overlays/collector-worker/small/ >  manifests/final/collector-worker.yaml

echo "step 8: genrating secure yaml"
kustomize build manifests/pjchart/templates/sysdig-cloud/secure/                           > manifests/final/secure.yaml

echo "step 9: generate ingress yaml"
kustomize build manifests/pjchart/templates/sysdig-cloud/ingress_controller/               > manifests/final/ingress.yaml
