#!/bin/bash

DIR="$(cd "$(dirname "$0")"; pwd -P)"
source "$DIR/shared-values.sh"

function log() {
  local info='\033[1;37m'  # white
  local error='\033[0;31m' # red
  local notice='\033[0;32m' # green
  local level="$1"
  local message="$2"
  local nocolor='\033[0m'

  case $level in
    info)
      echo -e "${info}${message}${nocolor}"
      ;;
    error)
      echo -e "${error}${message}${nocolor}"
      ;;
    notice)
      echo -e "${notice}${message}${nocolor}"
      ;;
    *)
      echo -e "${info}${message}${nocolor}"
  esac
}

function is_pod_ready() {
  [[  "$(kubectl -n "${K8S_NAMESPACE}" get po "$1" -o 'jsonpath={.status.conditions[?(@.type=="Ready")].status}')" == 'True' ]]
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
  log notice "Checking for Pods to be Ready  Will check every $interval seconds"
    while true; do
    pods="$(kubectl -n "${K8S_NAMESPACE}" get po -o 'jsonpath={.items[*].metadata.name}')"
    if pods_ready "${pods}"; then
      log info "All Pods Ready.....Continuing"
      return 0
    else
      sleep "$interval"
      if [[ $(( "$attempts" % 5 )) == 0 ]]; then
        if [[ $(( "$attempts" % 30 )) == 0 ]]; then
          log error "We have checked $attempts times. Its talking too long deploy bailing out. Please contact support."
          exit 3
         fi
        log error "We have checked $attempts times"
      fi
      attempts=$((attempts + 1))
    fi
  done
  }
