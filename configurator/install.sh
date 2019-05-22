#!/bin/ash

APPS=$(cat /sysdig-chart/values.yaml | yq .apps | tr -d '"')
echo ${APPS}
SECURE=false
for app in ${APPS}
do
 if [[ ${app} == "secure" ]]; then
  SECURE=true
 fi
done


SCRIPTS=$(cat /sysdig-chart/values.yaml | yq .scripts | tr -d '"')
echo ${SCRIPTS}
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

if [[ ${DEPLOY} == true ]];
then
  echo "Deploying Monitor..."
  /sysdig-chart/monitor.sh
  if [[ ${SECURE} == true ]];
  then
    echo "Deploying Secure..."
    /sysdig-chart/secure.sh
  fi
fi