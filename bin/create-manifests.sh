#!/bin/bash

SDC_HOME="../"
SDC_CONFIG="$SDC_HOME/etc/config"
SDC_TEMPLATES="$SDC_CONFIG/templates"
SDC_SETTINGS_FILE="$SDC_CONFIG/sdc-settings.yaml"
PVC_TYPE="$(egrep 'storageclassName'  $SDC_SETTINGS_FILE |egrep -v '#'|awk -F: '{print $2}')"


#create manifests for configmaps
kontemplate template $SDC_SETTINGS_FILE -i templates/configmaps/ > $SDC_HOME/etc/config/sdc-config.yaml

#create manifests for datastores

if [ $PVC_TYPE == "gce-pd" ]; then
	kontemplate template $SDC_SETTINGS_FILE -i templates/datastores/storageclasses/gce-pd/ > $SDC_HOME/datastores/storageclasses/sdc-storageclass.yaml

elif [ $PVC_TYPE == "aws-io1" ]; then
	kontemplate template $SDC_SETTINGS_FILE -i templates/datastores/storageclasses/aws-io1/ > $SDC_HOME/datastores/storageclasses/sdc-storageclass.yaml

elif [ $PVC_TYPE -eq "aws-gp2" ]; then
	kontemplate template $SDC_SETTINGS_FILE -i templates/datastores/storageclasses/aws-gp2/ > $SDC_HOME/datastores/storageclasses/sdc-storageclass.yaml
fi


kontemplate template $SDC_SETTINGS_FILE -i templates/datastores/cassandra/ > $SDC_HOME/datastores/sdc-cassandra.yaml
kontemplate template $SDC_SETTINGS_FILE -i templates/datastores/elasticsearch/ > $SDC_HOME/datastores/sdc-elasticsearch.yaml
kontemplate template $SDC_SETTINGS_FILE -i templates/datastores/mysql/master/ > $SDC_HOME/datastores/sdc-mysql-master.yaml
kontemplate template $SDC_SETTINGS_FILE -i templates/datastores/mysql/slaves/ > $SDC_HOME/datastores/sdc-mysql-slaves.yaml
kontemplate template $SDC_SETTINGS_FILE -i templates/datastores/redis/master/ > $SDC_HOME/datastores/sdc-redis-master.yaml
kontemplate template $SDC_SETTINGS_FILE -i templates/datastores/redis/slaves/ > $SDC_HOME/datastores/sdc-redis-slaves.yaml

#create manifests for backend components
kontemplate template $SDC_SETTINGS_FILE -i templates/backend/api > $SDC_HOME/backend/sdc-api.yaml
kontemplate template $SDC_SETTINGS_FILE -i templates/backend/collector > $SDC_HOME/backend/sdc-collector.yaml
kontemplate template $SDC_SETTINGS_FILE -i templates/backend/worker > $SDC_HOME/backend/sdc-worker.yaml

#create manifests for frontend (agents)
kontemplate template $SDC_SETTINGS_FILE -i templates/frontend > $SDC_HOME/frontend/sdc-agent-daemonset.yaml

