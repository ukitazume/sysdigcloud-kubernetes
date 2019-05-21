#!/bin/bash

#Echo function
function broadcast() {
  WHITE='\033[1;37m'
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  PURPLE='\033[0;35m'
  NC='\033[0m'
  
  if [ $1 = 'w' ]; then
     echo -e "${WHITE}*******************$2*******************${NC}"
  elif [ $1 = 'r' ]; then 
     echo -e "${RED}*******************$2*******************${NC}"
  elif [ $1 = 'g' ]; then
     echo -e "${GREEN}*******************$2*******************${NC}"
  elif [ $1 = 'p' ]; then
     echo -e "${PURPLE}*******************$2*******************${NC}"
  fi
  }

#Function for kubectl apply in sysdigcloud namespace
function ka() {
  kubectl -n sysdigcloud apply -f $1
  }

  #Function for kubectl apply in sysdig-agents namespace
function kaa() {
  kubectl -n sysdig-agents apply -f $1
  }

#function for kubectl create in sysdigcloud
function kc() {
  kubectl -n sysdigcloud create $1
  }

  #function for kubectl create sysdig-agents
function kca() {
  kubectl -n sysdig-agents create $1
  }

#function for kubectl create namespace
function kcns() {
  kubectl create namespace $1
  }

#function to get sysdig user
function get_sysdig_user() {
  sysdigcloud_user=$(grep "sysdigcloud.default.user:" sysdigcloud/config.yaml | awk {'print $2'})
  }

#function to get sysdig pass
function get_sysdig_pass() {
  sysdigcloud_pass=$(grep "sysdigcloud.default.user.password:" sysdigcloud/config.yaml | awk {'print $2'})
  }

function get_api_url() {
  api_url=$(grep api.url sysdigcloud/config.yaml | awk {'print $2'})
  }

function get_access_key() {
  get_api_url
  get_sysdig_user
  get_sysdig_pass
  accesskey=$(curl -s -k "$api_url/api/login" -H 'X-Sysdig-Product: SDC' -H 'Content-Type: application/json' --compressed --data-binary '{"username":"'$sysdigcloud_user'","password":"'$sysdigcloud_pass'"}' -c /tmp/sysdig.monitor.cookie | jq . | grep accessKey | awk 'NR==1 {print $2}')
  accesskey=$(echo $accessKey | sed -e 's/^"//' -e 's/"$//' <<<"$accesskey")
  }

function get_monitor_api_key() {
  get_api_url
  get_sysdig_user
  get_sysdig_pass
  monitor_api_key=$(curl -s -k -X GET  "$api_url/api/token" -H 'X-Sysdig-Product: SDC' -H 'Content-Type: application/json' --compressed --data-binary '{"username":"'$sysdigcloud_user'","password":"'$sysdigcloud_pass'"} ' -b /tmp/sysdig.monitor.cookie | jq . | grep key | awk {'print $2'})
  monitor_api_key=$(echo $monitor_api_key | sed -e 's/^"//' -e 's/"$//' <<<"$monitor_api_key")
  }

function get_secure_api_key() {
  get_api_url
  get_sysdig_user
  get_sysdig_pass
  secure_cookie=$(curl -s -k "$api_url/api/login" -H 'X-Sysdig-Product: SDS' -H 'Content-Type: application/json' --compressed --data-binary '{"username":"'$sysdigcloud_user'","password":"'$sysdigcloud_pass'"}' -c /tmp/sysdig.secure.cookie | jq . | grep accessKey | awk 'NR==1 {print $2}' > /dev/null)
  secure_api_key=$(curl -s -k -X GET  "$api_url/api/token" -H 'X-Sysdig-Product: SDS' -H 'Content-Type: application/json' --compressed --data-binary '{"username":"'$sysdigcloud_user'","password":"'$sysdigcloud_pass'"} ' -b /tmp/sysdig.secure.cookie | jq . | grep key | awk {'print $2'})
  secure_api_key=$(echo $secure_api_key | sed -e 's/^"//' -e 's/"$//' <<<"$secure_api_key")
  }

#Function to update all the ingress files with api.url from configmap
function fix_ingress() {
  orig=$(grep host: sysdigcloud/api-ingress-with-secure.yaml | awk {'print $3'})
  sysdig_url=$(grep api.url sysdigcloud/config.yaml | cut -d ':' -f3 | sed 's/\/\///g')
  broadcast 'g' "Your New Sysdig URL"
  echo $sysdig_url

  broadcast 'g' "Your Old Entry"
  echo $orig

  broadcast 'g' "Fixing Ingress files"
  sed -i -e "s/$orig/$sysdig_url/g" sysdigcloud/api-ingress.yaml
  sed -i -e "s/$orig/$sysdig_url/g" sysdigcloud/api-ingress-with-secure.yaml
  }

#Function to fix cname.json and then autocreate route53 record for Sysdig Deployment
function cname_manipulation() {
  aws_lb=$(kubectl get services -owide -n sysdigcloud | grep haproxy-ingress-lb-service | awk {'print $4'})
  orig_lb_ip=$(grep ResourceRecords cname.json | awk {'print $4'} | cut -d'"' -f2)
  orig_cname=$(grep Name cname.json | cut -d'"' -f4)
  sysdig_url=$(grep api.url sysdigcloud/config.yaml | cut -d ':' -f3 | sed 's/\/\///g')
  cname_action=$(grep Action cname.json | cut -d '"' -f4)

  while [ "$aws_lb" = "<pending>" ]; do 
    broadcast 'r' "Waiting on AWS Load Balancer.  Sleeping for 10 seconds"
    sleep 10s
    aws_lb=$(kubectl get services -owide -n sysdigcloud | grep haproxy-ingress-lb-service | awk {'print $4'})
  done

  broadcast 'g' "Your AWS_LB"
  echo $aws_lb

  broadcast 'g' "Original LB CNAME"
  echo $orig_lb_ip

  broadcast 'g' "Fixing CNAME.json"
  sed -i -e "s/$orig_lb_ip/$aws_lb/g" cname.json
  sed -i -e "s/$orig_cname/$sysdig_url/g" cname.json
  
  broadcast 'g' "Changing CNAME.json Action"
  sed -i -e "s/$cname_action/UPSERT/g" cname.json

  broadcast 'g' "Applying LB to CNAME in Route53" 
  aws route53 change-resource-record-sets --hosted-zone-id Z26FQOXWCHEUX --change-batch file://cname.json
  }

deploy_agents() {
  
  cce=$(grep collector: agents/agent_config.yaml)
  sysdig_url=$(grep api.url sysdigcloud/config.yaml | cut -d ':' -f3 | sed 's/\/\///g')
  
  broadcast 'g' "Deploying Agents"
  get_api_url
  broadcast 'p' "Your URL is $api_url"
  get_access_key
  broadcast 'p' "Your Access Key is: $accesskey"
  get_monitor_api_key
  broadcast 'p' "Your Monitor API Key is: $monitor_api_key"
  get_secure_api_key
  broadcast 'p' "Your Secure  API Key is: $secure_api_key"

  broadcast 'g' "Creating Namespace sysdig-agents"
  kcns sysdig-agents

  broadcast 'g' "Creating Secret for AccessKey"
  get_access_key
  kc "-n sysdig-agents secret generic sysdig-agent --from-literal=access-key=$accesskey"

  broadcast 'g' "Fixing Collector Endpoints"
  sed -i -e "s/$cce/     collector: $sysdig_url/g" agents/agent_config.yaml

  broadcast 'g' "Creating Clusterrole"
  kaa agents/agent_clusterrole.yaml

  broadcast 'g' "Creating sysdig-agent Service Account"
  kca "serviceaccount sysdig-agent"

  broadcast 'g' "Creating ClusterRoleBinding"
  kubectl create clusterrolebinding sysdig-agent --clusterrole=sysdig-agent --serviceaccount=sysdig-agents:sysdig-agent

  broadcast 'g' "Deploying Agent Config"
  kaa agents/agent_config.yaml

  broadcast 'g' "Deploying Agent Service"
  kaa agents/sysdig-agent-service.yaml

  broadcast 'g' "Deploying Agents"
  kaa agents/agent_deployment.yaml

  broadcast 'w' "It will take about two minutes for the agents to come up...."
  }

function deploy_watchtower() {
  get_sysdig_user
  get_sysdig_pass
  get_api_url
  get_monitor_api_key

  broadcast 'g' "Deploying Dashboards"
  for raw_json in watchtower/dashboards.bash/*.json; do
      pretty_json=`cat $raw_json`

      curl -kX POST \
          -d "$pretty_json" \
           -H "Authorization: Bearer $monitor_api_key" \
           -H "Content-Type: application/json" \
           --output /dev/null --show-error --fail --silent \
           "$api_url"/ui/dashboards/
  done
  
  broadcast 'w' "Watchtower Dashboards Deployed....."
  }

function setup_scanning() {
  get_api_url
  get_secure_api_key
  get_sysdig_user
  get_sysdig_pass
  quay_user=$(grep dockerconfigjson: sysdigcloud/pull-secret.yaml | awk {'print $2'} | xargs echo | base64 -d | grep \"auth\": | awk {'print $2}' | cut -d '"' -f2 | base64 -d | cut -d ':' -f1)
  quay_pass=$(grep dockerconfigjson: sysdigcloud/pull-secret.yaml | awk {'print $2'} | xargs echo | base64 -d | grep \"auth\": | awk {'print $2}' | cut -d '"' -f2 | base64 -d | cut -d ':' -f2)
   
  #Setting Up anchore-cli
  export ANCHORE_CLI_SSL_VERIFY=n
  export ANCHORE_CLI_URL=$api_url/api/scanning/v1/anchore
  export ANCHORE_CLI_USER=$secure_api_key
  export ANCHORE_CLI_PASS=

  broadcast 'g' "Adding Quay Registry to Scanning" 
  anchore-cli registry add quay.io $quay_user $quay_pass --skip-validate > /dev/null
  #anchore-cli repo add couchbase > /dev/null
  #anchore-cli repo add busybox > /dev/null
  #anchore-cli repo add nginx > /dev/null
  #anchore-cli repo add wordpress > /dev/null
  #anchore-cli repo add couchbas > /dev/null
  #anchore-cli repo add busybox > /dev/null
  #anchore-cli repo add nginx > /dev/null
  #anchore-cli repo add wordpress > /dev/null

  #Create unscanned image alerts.
  broadcast 'g' "Creating Alert For Unscanned Images"
  curl --output /dev/null --show-error --fail --silent -k -X POST \
  $api_url/api/scanning/v1/alerts/ \
  -H 'Authorization: bearer '$secure_api_key'' \
  -H 'Content-Type: application/json' \
  -H 'X-Sysdig-Product: SDS' \
  -d '{
            "enabled": true,
            "name": "Scan Unscanned Image",
            "description": "",
            "scope": "",
            "triggers": {
                "unscanned": true,
                "failed": true
            },
            "autoscan": true,
            "notificationChannelIds": []
      }'
   }  

function update_falco_rules() {
  get_api_url
  get_sysdig_user
  get_sysdig_pass

  broadcast 'g' "Updating Falco Rules"
  docker run --rm --name falco-rules-installer -it -e DEPLOY_HOSTNAME=$api_url -e DEPLOY_USER_NAME=$sysdigcloud_user -e DEPLOY_USER_PASSWORD=$sysdigcloud_pass -e VALIDATE_RULES=yes -e DEPLOY_RULES=yes -e CREATE_NEW_POLICIES=no -e SDC_SSL_VERIFY=false sysdig/falco_rules_installer:latest &>/dev/null
  broadcast 'w' "Falo Rules Updated...."
  }

function is_pod_ready() {
  [[  "$(kubectl -n sysdigcloud get po "$1" -o 'jsonpath={.status.conditions[?(@.type=="Ready")].status}')" == 'True' ]]
   }

function pods_ready() {
  local pod
  [[ "$#" == 0 ]] && return 0

  for pod in $pods;do
    is_pod_ready $pod || return 1
  done

  return 0
  }

function wait_for_pods() {
  attempts=1
  interval=$1
  broadcast 'g' "Checking for Pods to be Ready  Will check every $interval seconds"
    while true; do
    pods="$(kubectl -n sysdigcloud get po -o 'jsonpath={.items[*].metadata.name}')"
    if pods_ready $pods; then
      broadcast 'w' "All Pods Ready.....Continuing"
      return 2
    else
      sleep "$interval"
      if ! (( $attempts % 5 )); then
        broadcast 'r' "We have checked $attempts times"
        attempts=$((attempts + 1))
      fi
      attempts=$((attempts + 1))
      interval=$((interval + 1 ))
    fi
  done
  }

function check_dns {
  aws_lb=$(kubectl get services -owide -n sysdigcloud | grep haproxy-ingress-lb-service | awk {'print $4'})
  attempts=1
  while  [ "$aws_lb" != "$dns_check" ]; do
    dns_name=$(grep api.url sysdigcloud/config.yaml | cut -d':' -f3 | sed 's/\/\///g')
    dns_check=$(dig +short $dns_name | awk NR==1 | sed 's/.$//')
    interval=$1
    if [ "$attempts" -eq 1 ]; then
      broadcast 'r'  "Waiting on DNS To Update.  We will check every $interval seconds"
    elif ! (( $attempts % 5 )); then
      broadcast 'r' "Still Waiting for DNS To Propogate....We have checked $attempts times"
    fi
    attempts=$((attempts + 1)) 
    sleep $interval
    done 
  broadcast 'w' "DNS propogated successfully"
  }

function update_k8_api() {
  export APISERVER_HOST=$(kubectl config view | grep api | grep server | awk {'print $2}' | cut -d '/' -f3)
  SSH_KEY=$1
  SSH_USER=$2
  MANIFEST=/etc/kubernetes/manifests/kube-apiserver.manifest  

  broadcast 'g' "Copying audit policy/webhook files to apiserver..."
  ssh -o "StrictHostKeyChecking=no" -i $SSH_KEY $SSH_USER@$APISERVER_HOST "sudo mkdir -p /var/lib/k8s_audit && sudo chown $SSH_USER /var/lib/k8s_audit" &>/dev/null
  scp -o "StrictHostKeyChecking=no" -i $SSH_KEY k8_audit/audit-policy.yaml $SSH_USER@$APISERVER_HOST:/var/lib/k8s_audit &>/dev/null
  scp -o "StrictHostKeyChecking=no" -i $SSH_KEY k8_audit/webhook-config.yaml $SSH_USER@$APISERVER_HOST:/var/lib/k8s_audit &>/dev/null
  scp -o "StrictHostKeyChecking=no" -i $SSH_KEY k8_audit/apiserver-config.patch.sh $SSH_USER@$APISERVER_HOST:/var/lib/k8s_audit &>/dev/null
  broadcast 'g' "Attempting To Patch kube-api"
  #ssh -o "StrictHostKeyChecking=no" -i $SSH_KEY $SSH_USER@$APISERVER_HOST "sudo bash /var/lib/k8s_audit/apiserver-config.patch.sh" &>/dev/null
  ssh -o "StrictHostKeyChecking=no" -i $SSH_KEY $SSH_USER@$APISERVER_HOST "if test -f "/tmp/kube-apiserver.yaml.patched";then echo "kube-api already patched.  Forcing Kubelet To Look At New Config" && sudo cp -p /tmp/kube-apiserver.manifest.original /etc/kubernetes/manifests/kube-apiserver.manifest && sudo bash /var/lib/k8s_audit/apiserver-config.patch.sh; else sudo bash /var/lib/k8s_audit/apiserver-config.patch.sh;fi"
  } 

function enable_k8s_audit() {
  k8_ssh_key=$1
  master_user=$2
  broadcast 'g' "Enabling K8s Audit Functionality On Master"
  AGENT_SERVICE_CLUSTERIP=$(kubectl -n sysdig-agents get service sysdig-agent -o=jsonpath={.spec.clusterIP}) envsubst < k8_audit/webhook-config.yaml.in > k8_audit/webhook-config.yaml
  update_k8_api $k8_ssh_key $master_user
  broadcast 'w' "K8's Audit Feature Enabled...."
  }

function cleanup_sysdig() {
  broadcast 'g' "Cleaning up all pvc"
  for i in `kubectl -n sysdigcloud get pvc | awk  'NR > 1 {print $1'}`;do kubectl -n sysdigcloud delete pvc $i;done
  
  broadcast 'g' "Cleaning up all pv"
  for i in `kubectl -n sysdigcloud get pv | awk 'NR > 1 {print $1'}`;do kubectl -n sysdigcloud delete pv $i;done

  broadcast 'g' "Cleaning up namespace sysdigcloud"
  kubectl delete ns sysdigcloud

  broadcast 'g' "Cleaning up namespace sysdig-agents"
  kubectl delete ns sysdig-agents

  broadcast 'g' "Removing CNAME Record from Route53"
  cname_action=$(grep Action cname.json | cut -d '"' -f4)
  sed -i -e "s/$cname_action/DELETE/g" cname.json
  aws route53 change-resource-record-sets --hosted-zone-id Z26FQOXWCHEUX --change-batch file://cname.json
  broadcast 'w' "Sysdig Fully Removed From Cluster"
  }

function openshift_prep() {
  broadcast 'g' "Labeling Nodes for Agent Deployment"
  oc label node --all "app=sysdig" --overwrite

  broadcast 'g' "Creating project sysdigcloud"
  oc adm new-project sysdigcloud
  
  broadcast 'g' "Giving root and privileged access to default user in sysdigcloud"
  oc adm policy add-scc-to-user anyuid -n sysdigcloud -z default
  oc adm policy add-scc-to-user privileged -n sysdigcloud -z default
  
  broadcast 'g' "Creating project sysdig-agents"
  oc adm new-project sysdig-agents --node-selector='app=sysdig'
  
  broadcast 'g' "Giving root and privileged access to sysdig-agent in project sysdig-agents"
  oc adm policy add-scc-to-user anyuid -n sysdig-agents -z sysdig-agent
  oc adm policy add-scc-to-user privileged -n sysdig-agents -z sysdig-agent
  }
