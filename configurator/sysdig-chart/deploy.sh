#!/bin/ash
set -euo pipefail

APPS=$(yq -r .apps /sysdig-chart/values.yaml)
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

