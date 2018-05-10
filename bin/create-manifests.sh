#!/bin/bash

SDC_HOME="$(dirname $0)/.."
SDC_CONFIG="$SDC_HOME/etc/config"
SDC_TEMPLATES="$SDC_CONFIG/templates"
SDC_SETTINGS_FILE="$SDC_CONFIG/sdc-settings.yaml"
PVC_TYPE="$(egrep 'storageclassName'  $SDC_SETTINGS_FILE |egrep -v '#'|awk -F: '{print $2}')"

KONTEMPLATE="kontemplate template $SDC_SETTINGS_FILE"

#create manifests for configmaps
${KONTEMPLATE} -i templates/configmaps/ > $SDC_HOME/etc/config/sdc-config.yaml

#create manifests for datastores

if [ $PVC_TYPE == "gce-pd" ]; then
    ${KONTEMPLATE} -i templates/datastores/storageclasses/gce-pd/ > $SDC_HOME/datastores/storageclasses/sdc-storageclass.yaml

elif [ $PVC_TYPE == "aws-io1" ]; then
    ${KONTEMPLATE} -i templates/datastores/storageclasses/aws-io1/ > $SDC_HOME/datastores/storageclasses/sdc-storageclass.yaml

elif [ $PVC_TYPE -eq "aws-gp2" ]; then
    ${KONTEMPLATE} -i templates/datastores/storageclasses/aws-gp2/ > $SDC_HOME/datastores/storageclasses/sdc-storageclass.yaml
fi

${KONTEMPLATE} -i templates/datastores/cassandra/ > $SDC_HOME/datastores/sdc-cassandra.yaml
${KONTEMPLATE} -i templates/datastores/elasticsearch/ > $SDC_HOME/datastores/sdc-elasticsearch.yaml
${KONTEMPLATE} -i templates/datastores/mysql/master/ > $SDC_HOME/datastores/sdc-mysql-master.yaml
${KONTEMPLATE} -i templates/datastores/mysql/slaves/ > $SDC_HOME/datastores/sdc-mysql-slaves.yaml
${KONTEMPLATE} -i templates/datastores/redis/master/ > $SDC_HOME/datastores/sdc-redis-master.yaml
${KONTEMPLATE} -i templates/datastores/redis/slaves/ > $SDC_HOME/datastores/sdc-redis-slaves.yaml

#create manifests for backend components
${KONTEMPLATE} -i templates/backend/api > $SDC_HOME/backend/sdc-api.yaml
${KONTEMPLATE} -i templates/backend/collector > $SDC_HOME/backend/sdc-collector.yaml
${KONTEMPLATE} -i templates/backend/worker > $SDC_HOME/backend/sdc-worker.yaml

#create manifests for frontend (agents)
${KONTEMPLATE} -i templates/frontend > $SDC_HOME/frontend/sdc-agent-daemonset.yaml
