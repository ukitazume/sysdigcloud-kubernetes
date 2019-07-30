#!/bin/bash

export TEMPLATE_DIR="/sysdig-chart"

function readConfigFromValuesYaml() {
  local valueToRead=$1
  local valueOverride=${2:-''}

  if [[ "$valueOverride" == "" ]]; then
    yq -r "$valueToRead" "${TEMPLATE_DIR}/values.yaml"
  else
    yq -r -s ".[0] * .[1] * .[2] | $valueToRead" "${TEMPLATE_DIR}/defaultValues.yaml" "${TEMPLATE_DIR}/values.yaml" "$valueOverride"
  fi
}

K8S_NAMESPACE="$(readConfigFromValuesYaml .namespace)"
export  K8S_NAMESPACE

export MANIFESTS="/manifests"
