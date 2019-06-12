#!/bin/ash
set -uo pipefail
#set variables
alias kubectl="oc-kubectl"
OPENSHIFT_URL=$(cat /sysdig-chart/values.yaml | yq .sysdig.openshiftUrl | tr -d '"')
OPENSHIFT_USER=$(cat /sysdig-chart/values.yaml | yq .sysdig.openshiftUser | tr -d '"')
OPENSHIFT_PASSWORD=$(cat /sysdig-chart/values.yaml | yq .sysdig.openshiftPassword | tr -d '"')
NAMESPACE=$(cat /sysdig-chart/values.yaml | yq .namespace | tr -d '"')
#login
oc login ${OPENSHIFT_URL} -u ${OPENSHIFT_USER} -p ${OPENSHIFT_PASSWORD}
OPENSHIFT_PROJECTS=$(oc projects -q)
PROJECT_PRESENT=false
for PROJECT in ${OPENSHIFT_PROJECTS}
do
  if [[ ${NAMESPACE} == ${PROJECT} ]]; then
    PROJECT_PRESENT=true
    echo "project is present in openshift"
  fi
done
echo $OPENSHIFT_PROJECTS
#create project
if [[ ${PROJECT_PRESENT} == false ]]; then
  oc new-project ${NAMESPACE}
else
  oc project ${NAMESPACE}
fi
#create permission for the project
oc adm policy add-scc-to-user anyuid -n ${NAMESPACE} -z default
oc adm policy add-scc-to-user privileged -n ${NAMESPACE} -z default

DNS_NAME=$(cat /sysdig-chart/values.yaml | yq .sysdig.dnsName | tr -d '"')

STATUS_API=$(oc get route sysdigcloud-api)
if $?; then
  echo "Route sysdigcloud-api exists."
else
  echo "Creating sysdigcloud-api route"
  oc create route edge sysdigcloud-api \
    --service=sysdigcloud-api \
    --cert=/manifests/certs/server.crt \
    --key=/manifests/certs/server.key \
    --port=8080 \
    --hostname=${DNS_NAME}
fi

STATUS_COLLECTOR=$(oc get route sysdigcloud-collector)
if $?; then
  echo "Route sysdigcloud-collector exists."
else
  echo "Creating route sysdigcloud-collector"
  oc create route passthrough sysdigcloud-collector \
    --service sysdigcloud-collector \
    --port=6443 \
    --hostname=collector-${DNS_NAME}
fi