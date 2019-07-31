#!/bin/bash

export TEMPLATE_DIR="/sysdig-chart"

function readConfigFromValuesYaml() {
  local valueToRead=$1
  local valuesYamlFile=$2

  yq -r -s ".[0] * .[1] | $valueToRead" "${TEMPLATE_DIR}/defaultValues.yaml" "$valuesYamlFile"
}

K8S_NAMESPACE="$(readConfigFromValuesYaml .namespace "$TEMPLATE_DIR/values.yaml")"
export  K8S_NAMESPACE

export MANIFESTS="/manifests"
