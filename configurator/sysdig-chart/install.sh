#!/bin/bash

DIR="$(cd "$(dirname "$0")"; pwd -P)"
source "$DIR/shared-values.sh"

set -euo pipefail
. /sysdig-chart/framework.sh

if [[ ! -f /manifests/values.yaml ]]; then
  log error "Please provide a values.yaml in your current working directory."
  log info "See: \\n\
  https://sysdig.atlassian.net/wiki/spaces/DEVOPS/pages/833978514/Onprem+Configurator  \\n\
  for guidance"
  exit 1
else
  cp /manifests/values.yaml /sysdig-chart/values.yaml
fi

SCRIPTS=$(yq -r .scripts "$TEMPLATE_DIR/values.yaml")
log info "${SCRIPTS}"

#set defaults
GENERATE=false
DEPLOY=false

for script in ${SCRIPTS}
do
 if [[ ${script} == "generate" ]];
 then
   GENERATE=true
 elif [[ ${script} == "deploy" ]];
 then
   DEPLOY=true
 fi
done

if [[ ${GENERATE} == "true" ]];
then
  log notice "Generating templates..."
  "$TEMPLATE_DIR/generate_templates.sh"
fi

DEPLOYMENT=$(yq -r .deployment "$TEMPLATE_DIR/values.yaml")
if [[ ${DEPLOYMENT} == "openshift" ]];
then
  "$TEMPLATE_DIR/openshift.sh"
fi

if [[ ${DEPLOY} == "true" ]];
then
  "$TEMPLATE_DIR/deploy.sh"
fi