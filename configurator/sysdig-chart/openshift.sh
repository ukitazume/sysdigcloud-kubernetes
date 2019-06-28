#!/bin/bash

set -uo pipefail
. /sysdig-chart/framework.sh

#set variables
alias kubectl="oc-kubectl"
OPENSHIFT_URL=$(yq -r .sysdig.openshiftUrl /sysdig-chart/values.yaml)
OPENSHIFT_USER=$(yq -r .sysdig.openshiftUser /sysdig-chart/values.yaml)
OPENSHIFT_PASSWORD=$(yq -r .sysdig.openshiftPassword /sysdig-chart/values.yaml)
NAMESPACE=$(yq -r .namespace /sysdig-chart/values.yaml)
#login
oc login "${OPENSHIFT_URL}" -u "${OPENSHIFT_USER}" -p "${OPENSHIFT_PASSWORD}"
OPENSHIFT_PROJECTS=$(oc projects -q)
PROJECT_PRESENT=false
for PROJECT in ${OPENSHIFT_PROJECTS}
do
  if [[ ${NAMESPACE} == "${PROJECT}" ]]; then
    PROJECT_PRESENT=true
    log info "project is present in openshift"
  fi
done
log info "$OPENSHIFT_PROJECTS"
#create project
if [[ ${PROJECT_PRESENT} == false ]]; then
  oc new-project "${NAMESPACE}"
else
  oc project "${NAMESPACE}"
fi
#create permission for the project
oc adm policy add-scc-to-user anyuid -n "${NAMESPACE}" -z default
oc adm policy add-scc-to-user privileged -n "${NAMESPACE}" -z default

DNS_NAME=$(yq -r .sysdig.dnsName /sysdig-chart/values.yaml)

if oc get route sysdigcloud-api; then
  log info "Route sysdigcloud-api exists."
else
  log info "Creating sysdigcloud-api route"
  oc create route edge sysdigcloud-api \
    --service=sysdigcloud-api \
    --cert=/manifests/certs/server.crt \
    --key=/manifests/certs/server.key \
    --port=8080 \
    --hostname="${DNS_NAME}"
fi

if oc get route sysdigcloud-collector; then
  log info "Route sysdigcloud-collector exists."
else
  log info "Creating route sysdigcloud-collector"
  oc create route passthrough sysdigcloud-collector \
    --service sysdigcloud-collector \
    --port=6443 \
    --hostname=collector-"${DNS_NAME}"
fi