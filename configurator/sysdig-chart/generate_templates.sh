#!/bin/ash
set -euo pipefail
export PATH=$PATH:/helm/linux-386/:/kubernetes:/kubernetes/kubernetes-cli
while getopts "m:s:" opt; do
  case ${opt} in
    m ) # process option a
      mode=$OPTARG
      echo "Mode selection $mode"
      ;;
    s ) # process option t
      size=$OPTARG
      echo "Size selection $size"
      ;;
    \? ) echo "Usage: cmd [-m monitor|monitor+secure] [-s small|medium|large]"
         exit 1
      ;;
  esac
done

echo "happy templating!! with mode $mode & size $size"

echo "step1: removing exiting manifests"
rm -rf /manifests/generated/ /manifests/sysdig-chart/

echo "step2: creating manifest dirs"
MANIFESTS=/manifests
GENERATED_DIR=$MANIFESTS/generated
mkdir $GENERATED_DIR

echo "step3: creating secret file - if it does not exist"
TEMPLATE_DIR=/sysdig-chart
SECRET_FILE=secrets-values.yaml
GENERATED_SECRET_FILE=$MANIFESTS/secrets-values.yaml
if [ -f "$GENERATED_SECRET_FILE" ]; then
    echo "$SECRET_FILE exists"
else
    echo "Secret file does not exist. Creating Secretfile"
    helm template -x templates/$SECRET_FILE $TEMPLATE_DIR/secret-generator > $GENERATED_SECRET_FILE
fi

echo "step4: running through helm template engine"
helm template -f $TEMPLATE_DIR/values.yaml -f $GENERATED_SECRET_FILE --output-dir $MANIFESTS $TEMPLATE_DIR

MANIFESTS_TEMPLATE_BASE=$MANIFESTS/sysdig-chart/templates/
GENERATE_CERTIFICATE=$(cat $TEMPLATE_DIR/values.yaml | yq .sysdig.certificate.generate)
GENERATED_CRT=$MANIFESTS/certs/server.crt
GENERATED_KEY=$MANIFESTS/certs/server.key
DNS_NAME=$(cat $TEMPLATE_DIR/values.yaml | yq .sysdig.dnsName)
mkdir $MANIFESTS_TEMPLATE_BASE/common-config/certs
if [ ! -d mkdir $MANIFESTS/certs]; then
  echo "Making certs manifests dir"
  mkdir $MANIFESTS/certs
fi
if [ "$GENERATE_CERTIFICATE" = true ]; then
  if [[ -f $GENERATED_KEY && -f $GENERATED_CRT ]]; then
    echo "Certificates are present. Copying the existing certs"
  else
    echo "Generating new certificate"
    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/C=US/ST=CA/L=SanFrancisco/O=ICT/CN=$DNS_NAME" -keyout $GENERATED_KEY -out $GENERATED_CRT
  fi
  cp $GENERATED_KEY $GENERATED_CRT $MANIFESTS_TEMPLATE_BASE/common-config/certs/
else
  CRT_FILE=$(cat $TEMPLATE_DIR/values.yaml | yq .sysdig.certificate.crt | tr -d '"')
  KEY_FILE=$(cat $TEMPLATE_DIR/values.yaml | yq .sysdig.certificate.key | tr -d '"')
  echo "Using provided certificates at crt:$CRT_FILE key:$KEY_FILE"
  if [[ -f $CRT_FILE && -f $KEY_FILE ]]; then
    cp $CRT_FILE $MANIFESTS_TEMPLATE_BASE/common-config/certs/server.crt
    cp $KEY_FILE $MANIFESTS_TEMPLATE_BASE/common-config/certs/server.key
  else
    echo "Cannot find certificate files. Exiting"
    exit 2
  fi
fi

echo "step5: generate commong files"
kustomize build $MANIFESTS_TEMPLATE_BASE/overlays/common-config/small                  > $GENERATED_DIR/common-config.yaml

echo "step 6: generate ingress yaml"
kustomize build $MANIFESTS_TEMPLATE_BASE/sysdig-cloud/ingress_controller               > $GENERATED_DIR/ingress.yaml

echo "step7:  Generating data-stores"
echo "step7a: data-stores cassandra"
echo "---" >>$GENERATED_DIR/infra.yaml
kustomize build $MANIFESTS_TEMPLATE_BASE/data-stores/overlays/cassandra/$size          >> $GENERATED_DIR/infra.yaml
echo "step7b: data-stores elasticsearch"
echo "---" >>$GENERATED_DIR/infra.yaml
kustomize build $MANIFESTS_TEMPLATE_BASE/data-stores/overlays/elasticsearch/$size      >> $GENERATED_DIR/infra.yaml
echo "step7c: data-stores mysql $size"
echo "---" >>$GENERATED_DIR/infra.yaml
kustomize build $MANIFESTS_TEMPLATE_BASE/data-stores/overlays/mysql/$size              >> $GENERATED_DIR/infra.yaml
if [ $mode = "monitor+secure" ]; then
  echo "step7d: data-stores postgres"
  echo "---" >>$GENERATED_DIR/infra.yaml
  kustomize build $MANIFESTS_TEMPLATE_BASE/data-stores/overlays/postgres/$size         >> $GENERATED_DIR/infra.yaml
else
  echo "skipping step7d: data-stores postgres - needed only for secure"
fi
if [ $size = "small" ]; then
  echo "step7e: data-stores redis-single small"
  echo "---" >>$GENERATED_DIR/infra.yaml
  kustomize build $MANIFESTS_TEMPLATE_BASE/data-stores/redis-single                    >> $GENERATED_DIR/infra.yaml
else
  echo "step7e: data-stores redis-ha $size"
  echo "---" >>$GENERATED_DIR/infra.yaml
  kustomize build $MANIFESTS_TEMPLATE_BASE/data-stores/overlays/redis-stateful/$size   >> $GENERATED_DIR/infra.yaml
fi

echo "step 8: Generating monitor"
echo "step 8a: generate monitor-api yamls"
kustomize build $MANIFESTS_TEMPLATE_BASE/sysdig-cloud/overlays/api/$size               > $GENERATED_DIR/api.yaml

echo "step 8b: generate monitor-collectorworker yamls"
kustomize build $MANIFESTS_TEMPLATE_BASE/sysdig-cloud/overlays/collector-worker/$size  > $GENERATED_DIR/collector-worker.yaml

if [ $mode = "monitor+secure" ]; then
  echo "step 9a: generating secure-scanning yaml"
  kustomize build $MANIFESTS_TEMPLATE_BASE/sysdig-cloud/overlays/secure/scanning/$size       > $GENERATED_DIR/scanning.yaml
  echo "step 9b: generating secure-anchore yaml"
  kustomize build $MANIFESTS_TEMPLATE_BASE/sysdig-cloud/overlays/secure/anchore/$size        > $GENERATED_DIR/anchore-core.yaml
  kustomize build $MANIFESTS_TEMPLATE_BASE/sysdig-cloud/overlays/secure/anchore/worker/$size > $GENERATED_DIR/anchore-worker.yaml
else
  echo "skipping step 9: genrating secure yaml - needed only for secure"
fi
