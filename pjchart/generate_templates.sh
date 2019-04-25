#!/bin/bash

echo "happy templating!!"

echo "step1: running through helm template engine"

helm template --values values.yaml --output-dir manifests/ .

echo "step x: genrating secure configs"

kustomize build manifests/pjchart/templates/apps/anchor/ > manifests/anchor_condig.yaml
