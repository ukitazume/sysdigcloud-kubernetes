#!/bin/bash

echo "happy templating!!"

echo "step1: removing exiting manifests"
rm -rf manifests/

echo "step2: creating manifest dirs"
GENERATED_DIR=manifests/generated
mkdir manifests && mkdir $GENERATED_DIR

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
kustomize build manifests/pjchart/templates/overlays/common-config/small/ > $GENERATED_DIR/common-config.yaml

echo "step 6: generate ingress yaml"
kustomize build manifests/pjchart/templates/sysdig-cloud/ingress_controller/               > $GENERATED_DIR/ingress.yaml

echo "step7:  Generating data-stores"
echo "step7a: data-stores cassandra"
echo "---" >>$GENERATED_DIR/infra.yaml
kustomize build manifests//pjchart/templates/data-stores/overlays/cassandra/small/    >> $GENERATED_DIR/infra.yaml
echo "step7b: data-stores elasticsearch"
echo "---" >>$GENERATED_DIR/infra.yaml
kustomize build manifests/pjchart/templates/data-stores/overlays/elasticsearch/small/ >> $GENERATED_DIR/infra.yaml
echo "step7c: data-stores mysql"
echo "---" >>$GENERATED_DIR/infra.yaml
kustomize build manifests//pjchart/templates/data-stores/overlays/mysql-single/small/ >> $GENERATED_DIR/infra.yaml
echo "step7d: data-stores postgres"
echo "---" >>$GENERATED_DIR/infra.yaml
kustomize build manifests//pjchart/templates/data-stores/overlays/postgres/small/     >> $GENERATED_DIR/infra.yaml
echo "step7e: data-stores redis"
echo "---" >>$GENERATED_DIR/infra.yaml
kustomize build manifests//pjchart/templates/data-stores/redis-single/                >> $GENERATED_DIR/infra.yaml

echo "step 8: Generating monitor"
echo "step 8a: generate monitor-api yamls"
kustomize build manifests//pjchart/templates/sysdig-cloud/overlays/api/small/              > $GENERATED_DIR/api.yaml

echo "step 8b: generate monitor-collectorworker yamls"
kustomize build manifests//pjchart/templates/sysdig-cloud/overlays/collector-worker/small/ > $GENERATED_DIR/collector-worker.yaml

echo "step 9: genrating secure yaml"
kustomize build manifests/pjchart/templates/sysdig-cloud/secure/                           > $GENERATED_DIR/secure.yaml

