#!/bin/ash
set -euo pipefail

SCRIPTS=$(cat /sysdig-chart/values.yaml | yq .scripts | tr -d '"')
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

if [[ ${GENERATE} == true ]];
then
  echo "Generating templates..."
  /sysdig-chart/generate_templates.sh
fi

DEPLOYMENT=$(cat /sysdig-chart/values.yaml | yq .deployment | tr -d '"')
if [[ ${DEPLOYMENT} == "openshift" ]];
then
  /sysdig-chart/openshift.sh
fi

if [[ ${DEPLOY} == true ]];
then
  /sysdig-chart/deploy.sh
fi
