#!/bin/bash

export TEMPLATE_DIR="/sysdig-chart"

K8S_NAMESPACE="$(yq -r .namespace $TEMPLATE_DIR/values.yaml)"
export  K8S_NAMESPACE
