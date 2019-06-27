#!/bin/bash

DIR="$(cd "$(dirname "$0")"; pwd -P)"
source "$DIR/shared-values.sh"

set -euo pipefail
. /sysdig-chart/framework.sh

APPS=$(yq -r .apps /sysdig-chart/values.yaml)
log info "${APPS}"
SECURE=false
for app in ${APPS}
do
 if [[ ${app} == "secure" ]]; then
  SECURE=true
 fi
done

log notice "Deploying Monitor..."
"$TEMPLATE_DIR/monitor.sh"
if [[ ${SECURE} == true ]];
then
  log notice "Deploying Secure..."
  "$TEMPLATE_DIR/secure.sh"
fi

