#!/bin/bash

export TEMPLATE_DIR="/sysdig-chart"

function readYaml() {
  local valueToRead=$1
  if [[ "$VALUES_OVERRIDE" == "" ]]; then
    yq -r "$valueToRead" "${TEMPLATE_DIR}/values.yaml"
  else
    yq -r -s ".[0] * .[1] | $valueToRead" "${TEMPLATE_DIR}/values.yaml" "$VALUES_OVERRIDE"
  fi
}

K8S_NAMESPACE="$(readYaml .namespace)"
export  K8S_NAMESPACE

export MANIFESTS="/manifests"
