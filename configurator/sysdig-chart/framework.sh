#!/bin/bash

NAMESPACE=$(yq -r .namespace /sysdig-chart/values.yaml)

#Echo function
function broadcast() {
  WHITE='\033[1;37m'
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  PURPLE='\033[0;35m'
  NC='\033[0m'

  if [[ "$1" = "w" ]]; then
     echo -e "${WHITE}$2${NC}"
  elif [[ "$1" = "r" ]]; then
     echo -e "${RED}$2${NC}"
  elif [[ "$1" = "g" ]]; then
     echo -e "${GREEN}$2${NC}"
  elif [[ "$1" = "p" ]]; then
     echo -e "${PURPLE}$2${NC}"
  elif [[ "$1" = "red" ]]; then
     echo -e "${RED}$2${NC}"
  elif [[ "$1" = "green" ]]; then
     echo -e "${GREEN}$2${NC}"
  fi
  }

function is_pod_ready() {
  [[  "$(kubectl -n "${NAMESPACE}" get po "$1" -o 'jsonpath={.status.conditions[?(@.type=="Ready")].status}')" == 'True' ]]
   }

function pods_ready() {
  local pod
  [[ "$#" == 0 ]] && return 0

  for pod in ${pods};do
    is_pod_ready "${pod}" || return 1
  done

  return 0
  }

function wait_for_pods() {
  attempts=1
  interval=$1
  broadcast 'g' "Checking for Pods to be Ready  Will check every $interval seconds"
    while true; do
    pods="$(kubectl -n "${NAMESPACE}" get po -o 'jsonpath={.items[*].metadata.name}')"
    if pods_ready "${pods}"; then
      broadcast 'w' "All Pods Ready.....Continuing"
      return 0
    else
      sleep "$interval"
      if [[ $(( "$attempts" % 5 )) == 0 ]]; then
        if [[ $(( "$attempts" % 30 )) == 0 ]]; then
          broadcast 'r' "We have checked $attempts times. Its talking too long deploy bailing out. Please contact support."
          exit 3
         fi
        broadcast 'r' "We have checked $attempts times"
      fi
      attempts=$((attempts + 1))
    fi
  done
  }
