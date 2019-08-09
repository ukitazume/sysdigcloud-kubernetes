#!/bin/bash

# shellcheck source=/dev/null
# Allow files generated in container be modifiable by host user
umask 000

#defaults to no overrides
VALUES_FILE=$1

DIR="$(cd "$(dirname "$0")"; pwd -P)"
source "$DIR/shared-values.sh"

set -euo pipefail
source "${TEMPLATE_DIR}/framework.sh"

function process_certs() {
  local generate_certificate=$1
  local generated_key=$2
  local generated_crt=$3
  local crt_file=$4
  local key_file=$5
  local dns_name=$6
  if [ "$generate_certificate" = "true" ]; then
    if [[ -f $generated_key && -f $generated_crt ]]; then
      log info "Certificates are present. Copying the existing certs"
    else
      log info "Generating new certificate"
      openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/C=US/ST=CA/L=SanFrancisco/O=ICT/CN=$dns_name" -keyout "$generated_key" -out "$generated_crt"
    fi
    cp "$generated_key" "$generated_crt" "$MANIFESTS_TEMPLATE_BASE/common-config/certs/"
  else
    log info "Using provided certificates at crt:$crt_file key:$key_file"
    if [[ -f $crt_file && -f $key_file ]]; then
      cp "$crt_file" "$MANIFESTS_TEMPLATE_BASE/common-config/certs/$(basename "$generated_crt")"
      cp "$key_file" "$MANIFESTS_TEMPLATE_BASE/common-config/certs/$(basename "$generated_key")"
    else
      log error "Cannot find certificate files. Exiting"
      exit 2
    fi
  fi
}

function validate_cert() {
  local dns_name=$1
  local server_cert=$2
  # credit:
  # https://unix.stackexchange.com/questions/103461/get-common-name-cn-from-ssl-certificate#comment283029_103464
  local common_name
  common_name=$(openssl x509 -noout -subject -in "$server_cert" | sed -e \
    's/^subject.*CN\s*=\s*\([a-zA-Z0-9\.\-]*\).*$/\1/' | tr -d ' ')

  set +e #disable exit on error for expr
  if [[ "$dns_name" != "$common_name" ]]; then
    # check that it is a wildcard common name and it matches the domain
    if expr "$common_name" : '.*\*' && \
      expr "$dns_name" : "${common_name//\*/.*}"; then
      log info "Certificate's common name '${common_name}' is a wildcard cert that
      matches domain name: ${dns_name}"
    else
      log info "Certificate's common name '${common_name}' does not match domain
      ${dns_name}, checking alternate name"
      IFS=', ' array=$(openssl x509 -noout -ext subjectAltName -in "$server_cert" | tail -n1)
      match="false"
      alt_dNS_NAME="DNS:${dns_name}"
      for domain in ${array}; do
      # example line: DNS:foo.bar.baz.com
        if [[ "$alt_dNS_NAME" == "$domain" ]]; then
          match="true"
          break
        fi
        if expr "$domain" : '.*\*' && \
          expr "$alt_dNS_NAME" : "${domain//\*/.*}"; then
          match="true"
          break
        fi
      done

      if [[ $match == "false" ]]; then
        log error "Certificate's common name or alternate names do not match domain name
        ${dns_name}"
        exit 2
      fi
    fi
  fi
  set -e #re-enable exit on error
}

#apps selection
APPS=$(readConfigFromValuesYaml .apps "$VALUES_FILE")
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
SIZE=$(readConfigFromValuesYaml .size "$VALUES_FILE")
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
    helm template -f "$TEMPLATE_DIR/defaultValues.yaml" -f "$VALUES_FILE" -x "templates/$SECRET_FILE" "$TEMPLATE_DIR/secret-generator" > "$GENERATED_SECRET_FILE"
fi

log info "step3.5: creating elasticsearch certs for Searchguard"

# This checks that the elasticsearch-tls-certs directory either does not exists
# or exists and is empty.
if [[ -z "$(ls -A "${MANIFESTS}/elasticsearch-tls-certs" 2> /dev/null)" ]]; then
  log info "Generating certs for Searchguard..."
  (cd /tools/
    ./sgtlstool.sh -c "$TEMPLATE_DIR/elasticsearch-tlsconfig.yaml" -ca -crt
    mv out "${MANIFESTS}/elasticsearch-tls-certs")
fi

log info "step4: running through helm template engine"
if [[ "$VALUES_FILE" == "" ]]; then
  helm template -f "$TEMPLATE_DIR/defaultValues.yaml" -f "$GENERATED_SECRET_FILE" -f "$TEMPLATE_DIR/values.yaml" --output-dir "$MANIFESTS" "$TEMPLATE_DIR"
else
  helm template -f "$TEMPLATE_DIR/defaultValues.yaml" -f "$GENERATED_SECRET_FILE" -f "$TEMPLATE_DIR/values.yaml" -f "$VALUES_FILE" --output-dir "$MANIFESTS" "$TEMPLATE_DIR"
fi

MANIFESTS_TEMPLATE_BASE="$MANIFESTS/$TEMPLATE_DIR/templates"

mkdir "$MANIFESTS_TEMPLATE_BASE/common-config/certs"
if [ ! -d "$MANIFESTS/certs" ]; then
  log info "Making certs manifests dir"
  mkdir "$MANIFESTS/certs"
fi


GENERATE_CERTIFICATE=$(readConfigFromValuesYaml .sysdig.certificate.generate "$VALUES_FILE")
GENERATE_COLLECTOR_CERTIFICATE=$(readConfigFromValuesYaml .sysdig.collector.certificate.generate "$VALUES_FILE")
GENERATED_CRT=$MANIFESTS/certs/server.crt
SUPPLIED_CRT="$MANIFESTS/$(readConfigFromValuesYaml .sysdig.certificate.crt "$VALUES_FILE")"
GENERATED_KEY=$MANIFESTS/certs/server.key
SUPPLIED_KEY="$MANIFESTS/$(readConfigFromValuesYaml .sysdig.certificate.key "$VALUES_FILE")"
COLLECTOR_CRT=$MANIFESTS/certs/collector.crt
SUPPLIED_COLLECTOR_CRT="$MANIFESTS/$(readConfigFromValuesYaml .sysdig.collector.certificate.crt "$VALUES_FILE")"
COLLECTOR_KEY=$MANIFESTS/certs/collector.key
SUPPLIED_COLLECTOR_KEY="$MANIFESTS/$(readConfigFromValuesYaml .sysdig.collector.certificate.key "$VALUES_FILE")"
DNS_NAME=$(readConfigFromValuesYaml .sysdig.dnsName "$VALUES_FILE")
COLLECTOR_DNS_NAME=$(readConfigFromValuesYaml .sysdig.collector.dnsName "$VALUES_FILE")

process_certs "$GENERATE_CERTIFICATE" "$GENERATED_KEY" "$GENERATED_CRT" "$SUPPLIED_CRT" "$SUPPLIED_KEY" "$DNS_NAME"
validate_cert "$DNS_NAME" "$MANIFESTS_TEMPLATE_BASE/common-config/certs/$(basename "$GENERATED_CRT")"

if [[ "$COLLECTOR_DNS_NAME" == null ]]; then
  log info "Collector domain not supplied"
else
  process_certs "$GENERATE_COLLECTOR_CERTIFICATE" "$COLLECTOR_KEY" "$COLLECTOR_CRT" "$SUPPLIED_COLLECTOR_CRT" "$SUPPLIED_COLLECTOR_KEY" "$COLLECTOR_DNS_NAME"
  validate_cert "$COLLECTOR_DNS_NAME" "$MANIFESTS_TEMPLATE_BASE/common-config/certs/$(basename "$COLLECTOR_CRT")"
fi

CUSTOM_CA=$(yq -r .sysdig.customCa "$TEMPLATE_DIR/values.yaml")
if [[ $CUSTOM_CA == "true" ]]; then
  CUSTOM_CERT=$MANIFESTS/certs/custom-ca.pem
  if [[ ! -f $CUSTOM_CERT ]]; then
    log error "Custom ca is set but not provided. Please provide a custom ca cert at certs/custom-ca.pem in the current working directory."
  else
    log info "Copying custom ca to $MANIFESTS_TEMPLATE_BASE/common-config/certs/"
    cp "$CUSTOM_CERT" "$MANIFESTS_TEMPLATE_BASE/common-config/certs/"
  fi
fi

log info "step5a: generate storage"
STORAGE_CLASS_PROVISIONER=$(readConfigFromValuesYaml .storageClassProvisioner "$VALUES_FILE")
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

IS_REDIS_HA=$(readConfigFromValuesYaml .sysdig.redisHa "$VALUES_FILE")
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

find "$MANIFESTS/$TEMPLATE_DIR" -type d -print0 | xargs -0 chmod 0777
find "$MANIFESTS/$TEMPLATE_DIR" -type f -print0 | xargs -0 chmod 0666

