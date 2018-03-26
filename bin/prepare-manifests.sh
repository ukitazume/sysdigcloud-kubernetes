#!/bin/bash

SDC_HOME="/Users/yoftimakonnen/sdc-kubernetes/auto/"
SDC_TEMPLATES="$SDC_HOME/templates"

#create configmaps

kubectl create configmap sysdigcloud-config \ 
	--from-env-file=$SDC_TEMPLATES/configmaps/sysdigcloud-configmap-env 

kubectl create configmap sysdigcloud-mysql-config \
	--from-file=$SDC_TEMPLATES/configmaps/mysql/master.cnf

kubectl create configmap sysdigcloud-mysql-config-slave \
	--from-file=$SDC_TEMPLATES/configmaps/mysql/slave.cnf

kubectl create configmap sysdigcloud-redis-config \
	--from-file=$SDC_TEMPLATES/configmaps/redis/master/redis.conf

kubectl create configmap sysdigcloud-redis-config-slave \
	--from-file=$SDC_TEMPLATES/configmaps/redis/slave/redis.conf

#create manifests
#kontemplate template prod-cluster-gke.yaml -i datastores/elasticsearch/