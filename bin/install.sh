#!/bin/bash

# Global Variables
NOW=$(date "+%Y.%m.%d-%H.%M.%S")
SDC_HOME=".."
LOG_FILE=$SDC_HOME/logs/install/install-$NOW.log
SETTINGS_FILE="$SDC_HOME/etc/config/sdc-settings.yaml"
NAMESPACE=$(egrep sysdigNamespace $SETTINGS_FILE |awk '{print $2}')
BACKEND_VERSION=$(egrep sysdigBackendImage $SETTINGS_FILE | awk -F: '{print $3}')
FRONTEND_VERSION=$(egrep sysdigFrontendImage $SETTINGS_FILE | awk -F: '{print $3}')
K8S_CLIENT_VERSION=$(kubectl version | egrep ^Client | awk -F, '{print $3}')
K8S_SERVER_VERSION=$(kubectl version | egrep ^Server | awk -F, '{print $3}')
CURRENT_CONTEXT=$(kubectl config get-contexts|egrep '^\*'|awk '{print $2}')
CURRENT_CLUSTER=$(kubectl config get-contexts|egrep '^\*'|awk '{print $3}')


error_exit()
{
	echo "$1" 1>&2 
	exit 1
}


print_env_variables()
{
	printf "LOG_FILE: %s\n" $LOG_FILE
	printf "SDC_HOME: %s\n" $SDC_HOME
	printf "SETTINGS_FILE: %s\n" $SETTINGS_FILE
	printf "NAMESPACE: %s\n" $NAMESPACE
	printf "BACKEND_VERSION: %s\n" $BACKEND_VERSION
	printf "FRONTEND_VERSION: %s\n" $FRONTEND_VERSION
	printf "K8S_CLIENT_VERSION: %s\n" $K8S_CLIENT_VERSION
	printf "K8S_SERVER_VERSION: %s\n" $K8S_SERVER_VERSION
	printf "CURRENT_CONTEXT: %s\n" $CURRENT_CONTEXT
	printf "CURRENT_CLUSTER: %s\n" $CURRENT_CLUSTER

}

print_banner()
{
	local cols=$(tput cols)
	local lines=$(tput lines)
	local numcols=$(((cols-6)/2))
	local numlines=$((lines/2))

	clear
	printf '\n'
	printf '+%.0s' {1..100}
	printf '\n'
	#tput cup $numlines $numcols
	printf "%s\n" "sysdigcloud on-prem installer"
	printf '\n%.0s' {1..3}
	printf "%s\n" "This is the Sysdig Monitor on-prem Kubernetes installer."
	printf "%s\n" "This installer assumes you have a running kubernetes cluster on AWS or GKE."
	printf "%s\n" "The executable 'kubectl' needs to be in your \$PATH with the context pointing to the right cluster."
	printf '\n%.0s' {1..3}
	printf "%s\n" "Your current kubectl client and server version are as follows:"
	printf "Client: %s\n" $K8S_CLIENT_VERSION
	printf "Server: %s\n" $K8S_SERVER_VERSION
	printf '\n%.0s' {1..2}
	printf "%s\n" "Your current Kubernetes context is:"
	printf "Current Context: %s\n" $CURRENT_CONTEXT
	printf "Current Cluster: %s\n" $CURRENT_CLUSTER
	printf '\n%.0s' {1..2}
	printf "%s\n" "Installer is configured for namespace $NAMESPACE."
	printf "%s\n" "Namespace $NAMESPACE will be created if it doesn't exist."
	printf '+%.0s' {1..100}
	printf '\n'
}

prompt_install()
{
	printf '\n'
	printf '\n'
	printf "%s\n" "Do you wish to install backend version $BACKEND_VERSION of sdc-kubernetes?"| tee -a $LOG_FILE
	select yn in "Yes" "No"; do
	    case $yn in
	        Yes ) break;;
	        No ) exit 1;;
	    esac
	done
	printf '\n'

}




create_namespace()
{
	# create namespace if it doesn't exist
	kubectl get namespace $NAMESPACE >> $LOG_FILE 2>&1
	if [ $? -ne 0 ]	; then
		kubectl create namespace $NAMESPACE >> $LOG_FILE 2>&1 
		if [ $? -eq 0 ] ; then
			echo "... namespace $NAMESPACE created."| tee -a $LOG_FILE
		else
			echo "... failed to create namespace $NAMESPACE."| tee -a $LOG_FILE
			exit 1
		fi
	else 
		echo "... namespace $NAMESPACE already exists."| tee -a $LOG_FILE
	fi
}


create_storageclasses()
{
	kubectl create -f $SDC_HOME/datastores/storageclasses/ >> $LOG_FILE 2>&1
	if [ $? -ne 0 ]; then
		echo "... failed to create storageclasses."| tee -a $LOG_FILE
		echo "     ... continuing."
	else
		echo "... storageclasses created."| tee -a $LOG_FILE
	fi	
}

create_ssl_certs()
{
	openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj \
	"/C=US/ST=CA/L=SanFrancisco/O=ICT/CN=sysdig.yoftilabs.com" \
	-keyout $SDC_HOME/etc/certs/server.key -out $SDC_HOME/etc/certs/server.crt >> $LOG_FILE 2>&1

	if [ $? -ne 0 ]; then
		echo "... failed to create ssl certs."| tee -a $LOG_FILE
		exit 1
	else
		echo "... ssl certs created."| tee -a $LOG_FILE
	fi

}

create_tls_secret()
{
	#create ssl-secret in kubernetes if it doesn't exist already
	kubectl get secret sysdigcloud-ssl-secret --namespace $NAMESPACE>> $LOG_FILE 2>&1
	if [ $? -ne 0 ]	; then
		kubectl create secret tls sysdigcloud-ssl-secret \
		--cert=$SDC_HOME/etc/certs/server.crt \
		--key=$SDC_HOME/etc/certs/server.key --namespace=$NAMESPACE >> $LOG_FILE 2>&1

		if [ $? -ne 0 ]; then
			echo "... failed to create ssl secret in kubernetes."| tee -a $LOG_FILE
			exit 1
		else
			echo "... ssl secret created in kubernetes. "| tee -a $LOG_FILE
		fi
	else
		echo "... ssl secret sysdigcloud-ssl-secret already exists."| tee -a $LOG_FILE
	fi	

}

create_configmaps()
{
	kubectl get configmap sysdigcloud-config --namespace $NAMESPACE>> $LOG_FILE 2>&1
	if [ $? -ne 0 ]	; then
		kubectl create -f $SDC_HOME/etc/config/sdc-config.yaml  --namespace $NAMESPACE
		if [ $? -ne 0 ]; then
			echo "... failed to create configmap in kubernetes."| tee -a $LOG_FILE
			exit 1
		else
			echo "... configmaps created in kubernetes. "| tee -a $LOG_FILE
		fi
	else
		echo "...  configmap already exists."| tee -a $LOG_FILE

	fi

}

start_datastores()
{
	kubectl create -f $SDC_HOME/datastores/sdc-mysql-master.yaml --namespace $NAMESPACE | tee -a $LOG_FILE
	kubectl create -f $SDC_HOME/datastores/sdc-redis-master.yaml --namespace $NAMESPACE | tee -a $LOG_FILE
	kubectl create -f $SDC_HOME/datastores/sdc-redis-slaves.yaml --namespace $NAMESPACE | tee -a $LOG_FILE
	kubectl create -f $SDC_HOME/datastores/sdc-cassandra.yaml  --namespace $NAMESPACE   | tee -a $LOG_FILE
	kubectl create -f $SDC_HOME/datastores/sdc-elasticsearch.yaml --namespace $NAMESPACE | tee -a $LOG_FILE
	kubectl create -f $SDC_HOME/datastores/sdc-mysql-slaves.yaml --namespace $NAMESPACE  | tee -a $LOG_FILE
}

start_backend()
{
	kubectl create  -f $SDC_HOME/backend/sdc-api.yaml --namespace $NAMESPACE       | tee -a $LOG_FILE
	kubectl create  -f $SDC_HOME/backend/sdc-worker.yaml --namespace $NAMESPACE    | tee -a $LOG_FILE
	kubectl create  -f $SDC_HOME/backend/sdc-collector.yaml --namespace $NAMESPACE | tee -a $LOG_FILE
}

print_post_install_banner()
{
	echo
	echo "... app successfully submitted to kubernetes ..."                            | tee -a $LOG_FILE
	echo "... monitor application by using \`watch kubectl get pods -n sysdigcloud \`" | tee -a $LOG_FILE
	echo "... wait until the sdc-api, sdc-collector and sdc-worker pods are started. " | tee -a $LOG_FILE
	echo
	echo
	echo 
	kubectl get pods -n $NAMESPACE| tee -a $LOG_FILE 	
}

#main{}
#print_env_variables
print_banner
prompt_install
create_namespace
create_storageclasses
create_ssl_certs
create_tls_secret
create_configmaps
start_datastores
echo "... about to sleep 90 before starting backend"
sleep 90
start_backend
