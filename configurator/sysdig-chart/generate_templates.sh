#!/bin/bash

# Allow files generated in container be modifiable by host user
umask 000

#defaults to no overrides
VALUES_OVERRIDE=""
while getopts ":f:" opt; do
  case $opt in
    f) VALUES_OVERRIDE="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done


DIR="$(cd "$(dirname "$0")"; pwd -P)"
source "$DIR/shared-values.sh"

set -euo pipefail
source "${TEMPLATE_DIR}/framework.sh"

#apps selection
APPS=$(readConfigFromValuesYaml .apps "$VALUES_OVERRIDE")
log info "${APPS}"
SECURE=false
for app in ${APPS}
do
 if [[ ${app} == "secure" ]]; then
  SECURE=true
 fi
done
log info "secure enabled: ${SECURE}"
#size selection
SIZE=$(readConfigFromValuesYaml .size "$VALUES_OVERRIDE")
log info "size selection: $SIZE"

log info "step1: removing exiting manifests"
rm -rf /manifests/generated/ "/manifests/$TEMPLATE_DIR"

log info "step2: creating manifest dirs"
GENERATED_DIR=$MANIFESTS/generated
mkdir -p "$GENERATED_DIR"

log info "step3: creating secret file - if it does not exist"
SECRET_FILE="secrets-values.yaml"
GENERATED_SECRET_FILE=$MANIFESTS/$SECRET_FILE
if [ -f "$GENERATED_SECRET_FILE" ]; then
    log info "$SECRET_FILE exists"
else
    log info "Secret file does not exist. Creating Secretfile"
    helm template -x "templates/$SECRET_FILE" "$TEMPLATE_DIR/secret-generator" > "$GENERATED_SECRET_FILE"
fi

log info "step3.5: creating elasticsearch certs for Searchguard"
if [[ -z "$(ls -A "${MANIFESTS}/elasticsearch-tls-certs")" ]]; then
  log info "Generating certs for Searchguard..."
  (cd /tools/
    ./sgtlstool.sh -c "$TEMPLATE_DIR/elasticsearch-tlsconfig.yaml" -ca -crt
    mv out "${MANIFESTS}/elasticsearch-tls-certs")
fi

log info "step4: running through helm template engine"
if [[ "$VALUES_OVERRIDE" == "" ]]; then
  helm template -f "$TEMPLATE_DIR/defaultValues.yaml" -f "$GENERATED_SECRET_FILE" -f "$TEMPLATE_DIR/values.yaml" --output-dir "$MANIFESTS" "$TEMPLATE_DIR"
else
  helm template -f "$TEMPLATE_DIR/defaultValues.yaml" -f "$GENERATED_SECRET_FILE" -f "$TEMPLATE_DIR/values.yaml" -f "$VALUES_OVERRIDE" --output-dir "$MANIFESTS" "$TEMPLATE_DIR"
fi

MANIFESTS_TEMPLATE_BASE="$MANIFESTS/$TEMPLATE_DIR/templates"
GENERATE_CERTIFICATE=$(readConfigFromValuesYaml .sysdig.certificate.generate "$VALUES_OVERRIDE")
CERT_FILE=$MANIFESTS/certs/server.crt
KEY_FILE=$MANIFESTS/certs/server.key
DNS_NAME=$(readConfigFromValuesYaml .sysdig.dnsName "$VALUES_OVERRIDE")

mkdir "$MANIFESTS_TEMPLATE_BASE/common-config/certs"
if [[ ! -d "$MANIFESTS/certs" ]]; then
  log info "Creating certs manifests dir"
  mkdir "$MANIFESTS/certs"
fi

if [[ -f "$CERT_FILE" && -f "$KEY_FILE" ]]; then
  log info "Certificates are present. Copying the existing certs"
  cp "$CERT_FILE" "$KEY_FILE" "$MANIFESTS_TEMPLATE_BASE/common-config/certs/"
else
  log info "Certificates are not present."
  if [[ "$GENERATE_CERTIFICATE" = "true" ]]; then
    log info "Generating new certificate"
    openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/C=US/ST=CA/L=SanFrancisco/O=ICT/CN=$DNS_NAME" -keyout "$KEY_FILE" -out "$CERT_FILE"
    log info "Certificates are generated. Copying the generated certs"
    cp "$CERT_FILE" "$KEY_FILE" "$MANIFESTS_TEMPLATE_BASE/common-config/certs/"
  else
    log error "Cannot find certificates and certificate generation is set to false. Exiting"
    exit 2
  fi
fi

SERVER_CERT=$MANIFESTS_TEMPLATE_BASE/common-config/certs/server.crt
# credit:
# https://unix.stackexchange.com/questions/103461/get-common-name-cn-from-ssl-certificate#comment283029_103464
COMMON_NAME=$(openssl x509 -noout -subject -in "$SERVER_CERT" | sed -e \
  's/^subject.*CN\s*=\s*\([a-zA-Z0-9\.\-]*\).*$/\1/' | tr -d ' ')

set +e #disable exit on error for expr
if [[ "$DNS_NAME" != "$COMMON_NAME" ]]; then
  # check that it is a wildcard common name and it matches the domain
  if expr "$COMMON_NAME" : '.*\*' && \
    expr "$DNS_NAME" : "${COMMON_NAME//\*/.*}"; then
    log info "Certificate's common name '${COMMON_NAME}' is a wildcard cert that
    matches domain name: ${DNS_NAME}"
  else
    log info "Certificate's common name '${COMMON_NAME}' does not match domain
    ${DNS_NAME}, checking alternate name"
    IFS=', ' array=$(openssl x509 -noout -ext subjectAltName -in "$SERVER_CERT" | tail -n1)
    MATCH="false"
    ALT_DNS_NAME="DNS:${DNS_NAME}"
    for domain in ${array}; do
    # example line: DNS:foo.bar.baz.com
      if [[ "$ALT_DNS_NAME" == "$domain" ]]; then
        MATCH="true"
        break
      fi
      if expr "$domain" : '.*\*' && \
        expr "$ALT_DNS_NAME" : "${domain//\*/.*}"; then
        MATCH="true"
        break
      fi
    done

    if [[ $MATCH == "false" ]]; then
      log error "Certificate's common name or alternate names do not match domain name
      ${DNS_NAME}"
      exit 2
    fi
  fi
fi
set -e #re-enable exit on error

CUSTOM_CA=$(readConfigFromValuesYaml .sysdig.certificate.customCA "$VALUES_OVERRIDE")
if [[ $CUSTOM_CA == "true" ]]; then
  CUSTOM_CERT="$MANIFESTS"/certs/custom-ca.pem
  if [[ ! -f "$CUSTOM_CERT" ]]; then
    log error "Custom CA is set but not provided. Please provide a custom CA cert at certs/custom-ca.pem in the current working directory."
  else
    log info "Copying custom CA to $MANIFESTS_TEMPLATE_BASE/common-config/certs/"
    cp "$CUSTOM_CERT" "$MANIFESTS_TEMPLATE_BASE/common-config/certs/"
  fi
else
  log info "Custom CA is set to $CUSTOM_CA. Continuing..."
fi

log info "step5a: generate storage"
STORAGE_CLASS_PROVISIONER=$(readConfigFromValuesYaml .storageClassProvisioner "$VALUES_OVERRIDE")
if [[ "$STORAGE_CLASS_PROVISIONER" == "hostPath" ]]; then
  log info "hostPath mode, skipping generating storage configs"
else
  kustomize build "$MANIFESTS_TEMPLATE_BASE/storage/"                                    > "$GENERATED_DIR/storage-class.yaml"
  if [[ "$STORAGE_CLASS_PROVISIONER" == "local" ]]; then
    cp "$MANIFESTS_TEMPLATE_BASE/sysdig-cloud/local-volume-provisioner/local-volume-provisioner.yaml" "$GENERATED_DIR/local-volume-provisioner.yaml"
  fi
fi

log info "step5b: generate common files"
kustomize build "$MANIFESTS_TEMPLATE_BASE/overlays/common-config/$SIZE"                  > "$GENERATED_DIR/common-config.yaml"

log info "step 6: generate ingress yaml"
kustomize build "$MANIFESTS_TEMPLATE_BASE/sysdig-cloud/ingress_controller"               > "$GENERATED_DIR/ingress.yaml"

log info "step7:  Generating data-stores"
log info "step7a: data-stores cassandra"
echo "---" >> "$GENERATED_DIR/infra.yaml"
kustomize build "$MANIFESTS_TEMPLATE_BASE/data-stores/overlays/cassandra/$SIZE"          >> "$GENERATED_DIR/infra.yaml"
log info "step7b: data-stores elasticsearch"
echo "---" >> "$GENERATED_DIR/infra.yaml"
kustomize build "$MANIFESTS_TEMPLATE_BASE/data-stores/overlays/elasticsearch/$SIZE"      >> "$GENERATED_DIR/infra.yaml"

log info "step7c: data-stores mysql $SIZE"
echo "---" >> "$GENERATED_DIR/infra.yaml"
kustomize build "$MANIFESTS_TEMPLATE_BASE/data-stores/overlays/mysql/$SIZE"              >> "$GENERATED_DIR/infra.yaml"
if [[ ${SECURE} == "true" ]]; then
  log info "step7d: data-stores postgres"
  echo "---" >> "$GENERATED_DIR/infra.yaml"
  kustomize build "$MANIFESTS_TEMPLATE_BASE/data-stores/overlays/postgres/$SIZE"         >> "$GENERATED_DIR/infra.yaml"
else
  log info "skipping step7d: data-stores postgres - needed only for secure"
fi

IS_REDIS_HA=$(readConfigFromValuesYaml .sysdig.redisHa "$VALUES_OVERRIDE")
if [[ ${IS_REDIS_HA} == "true" ]]; then
  log info "step7e: data-stores redis $SIZE"
  echo "---" >> "$GENERATED_DIR/infra.yaml"
  kustomize build "$MANIFESTS_TEMPLATE_BASE/data-stores/redis-ha/"                       >> "$GENERATED_DIR/infra.yaml"
else
  log info "step7e: data-stores redis-ha $SIZE"
  echo "---" >> "$GENERATED_DIR/infra.yaml"
  kustomize build "$MANIFESTS_TEMPLATE_BASE/data-stores/redis/"                          >> "$GENERATED_DIR/infra.yaml"
fi


log info "step 8: Generating monitor"
log info "step 8a: generate monitor-api yamls"
kustomize build "$MANIFESTS_TEMPLATE_BASE/sysdig-cloud/overlays/api/$SIZE"               > "$GENERATED_DIR/api.yaml"

log info "step 8b: generate monitor-collectorworker yamls"
kustomize build "$MANIFESTS_TEMPLATE_BASE/sysdig-cloud/overlays/collector-worker/$SIZE"  > "$GENERATED_DIR/collector-worker.yaml"

if [[ ${SECURE} == "true" ]]; then
  log info "step 9a: generating secure-scanning yaml"
  kustomize build "$MANIFESTS_TEMPLATE_BASE/sysdig-cloud/overlays/secure/scanning/$SIZE"       > "$GENERATED_DIR/scanning.yaml"
  log info "step 9b: generating secure-anchore yaml"
  kustomize build "$MANIFESTS_TEMPLATE_BASE/sysdig-cloud/overlays/secure/anchore/$SIZE"        > "$GENERATED_DIR/anchore-core.yaml"
  kustomize build "$MANIFESTS_TEMPLATE_BASE/sysdig-cloud/overlays/secure/anchore/worker/$SIZE" > "$GENERATED_DIR/anchore-worker.yaml"
else
  log info "skipping step 9: genrating secure yaml - needed only for secure"
fi
