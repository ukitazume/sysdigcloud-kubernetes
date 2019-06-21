#!/bin/ash
set -euo pipefail
. /sysdig-chart/framework.sh

APPS=$(yq -r .apps /sysdig-chart/values.yaml)
echo ${APPS}
SECURE=false
for app in ${APPS}
do
 if [[ ${app} == "secure" ]]; then
  SECURE=true
 fi
done

broadcast "green" "Deploying Monitor..."
/sysdig-chart/monitor.sh
if [[ ${SECURE} == true ]];
then
  broadcast "green" "Deploying Secure..."
  /sysdig-chart/secure.sh
fi

