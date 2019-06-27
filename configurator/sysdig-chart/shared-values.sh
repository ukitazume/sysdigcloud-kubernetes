#!/bin/bash

TEMPLATE_DIR="/sysdig-chart"
K8S_NAMESPACE="$(yq -r .namespace $TEMPLATE_DIR/values.yaml)"
