#!/bin/ash

set -euo pipefail
. /sysdig-chart/framework.sh

if [[ ! -f /manifests/values.yaml ]]; then
  broadcast "red" "Please provide a values.yaml in your current working directory."
  echo -e "See: \\n\
  https://sysdig.atlassian.net/wiki/spaces/DEVOPS/pages/833978514/Onprem+Configurator  \\n\
  for guidance"
  exit 1
else
  cp /manifests/values.yaml /sysdig-chart/values.yaml
fi

SCRIPTS=$(yq -r .scripts /sysdig-chart/values.yaml)
echo ${SCRIPTS}

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
  broadcast "green" "Generating templates..."
  /sysdig-chart/generate_templates.sh
fi

DEPLOYMENT=$(yq -r .deployment /sysdig-chart/values.yaml)
if [[ ${DEPLOYMENT} == "openshift" ]];
then
  /sysdig-chart/openshift.sh
fi

if [[ ${DEPLOY} == "true" ]];
then
  /sysdig-chart/deploy.sh
fi
