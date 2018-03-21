#!/bin/bash

SDC_HOME="/Users/yoftimakonnen/sdc-kubernetes/auto/"
SDC_TEMPLATES="$SDC_HOME/templates"


#create configmaps

kubectl create configmap sysdigcloud-config --from-env-file=$SDC_TEMPLATES/configmaps/sysdigcloud-configmap-env

kubectl create configmap sysdigcloud-mysql-config --from-file=$SDC_TEMPLATES/configmaps/mysql/master.cnf

kubectl create configmap sysdigcloud-mysql-config-slave  --from-file=$SDC_TEMPLATES/configmaps/mysql/slave.cnf

kubectl create configmap sysdigcloud-redis-config --from-file=$SDC_TEMPLATES/configmaps/redis/master/redis.conf

kubectl create configmap sysdigcloud-redis-config-slave  --from-file=$SDC_TEMPLATES/configmaps/redis/slaves/redis.conf

#create manifests
cd $SDC_TEMPLATES

kontemplate template prod-cluster-gke.yaml -i datastores/storageclasses/gce-pd > $SDC_HOME/datastores/storageclasses/gce-pd.yaml
kontemplate template prod-cluster-gke.yaml -i datastores/cassandra/ > $SDC_HOME/datastores/sdc-cassandra.yaml
kontemplate template prod-cluster-gke.yaml -i datastores/elasticsearch/ > $SDC_HOME/datastores/sdc-elasticsearch.yaml
kontemplate template prod-cluster-gke.yaml -i datastores/mysql/master/ > $SDC_HOME/datastores/sdc-mysql-master.yaml
kontemplate template prod-cluster-gke.yaml -i datastores/mysql/slaves/ > $SDC_HOME/datastores/sdc-mysql-slaves.yaml
kontemplate template prod-cluster-gke.yaml -i datastores/redis/master/ > $SDC_HOME/datastores/sdc-redis-master.yaml
kontemplate template prod-cluster-gke.yaml -i datastores/redis/slaves/ > $SDC_HOME/datastores/sdc-redis-slaves.yaml

kontemplate template prod-cluster-gke.yaml -i backend/api > $SDC_HOME/backend/sdc-api.yaml
kontemplate template prod-cluster-gke.yaml -i backend/collector > $SDC_HOME/backend/sdc-collector.yaml
kontemplate template prod-cluster-gke.yaml -i backend/worker > $SDC_HOME/backend/sdc-worker.yaml

