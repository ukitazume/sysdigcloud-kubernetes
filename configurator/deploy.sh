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

echo "Deploying Monitor..."
/sysdig-chart/monitor.sh
if [[ ${SECURE} == true ]];
then
  echo "Deploying Secure..."
  /sysdig-chart/secure.sh
fi

