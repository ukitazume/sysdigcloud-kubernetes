#!/bin/bash
set -x

function print_usage() {
  echo "Usage: ./generate_cert_secrets.sh <namespace> <tls-config-file>"
  echo
  echo "Used to generate the node/admin certs required for the SearchGuard Elasticsearch plugin"
  exit 1
}


if [ -z "$1" ] ; then
  echo "Namespace not provided" >&2
  print_usage()
fi

if [ -z "$2" ] ; then
  echo "tlsconfig file not provided" >&2
  print_usage()
fi

NAMESPACE=$1
CONFIG_FILE=$2
echo "generating certs for namespace: $NAMESPACE"
curl https://search.maven.org/remotecontent?filepath=com/floragunn/search-guard-tlstool/1.6/search-guard-tlstool-1.6.tar.gz | tar xzv
pushd tools/
./sgtlstool.sh -c $CONFIG_FILE -ca
kubectl -n $NAMESPACE create secret generic ca-certs --from-file=out -o yaml --dry-run > es-sg-certs.yml
popd
