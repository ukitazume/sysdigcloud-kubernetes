#!/bin/bash

# Allow files generated in container be modifiable by host user
umask 000

set -euo pipefail

DIR="$(cd "$(dirname "$0")"; pwd -P)"
source "$DIR/shared-values.sh"
. "${TEMPLATE_DIR}/framework.sh"

if [[ ! -S /var/run/docker.sock ]]; then
  log error "Please mount the docker socket at /var/run/docker.sock, e.g:
  by passing '-v /var/run/docker.sock:/var/run/docker.sock' to the docker
  command you ran"
  exit 1
fi

DOCKER_REGISTRY=$(yq -r .airgapped_registry_name /sysdig-chart/values.yaml)
DOCKER_USERNAME=$(yq -r .airgapped_registry_username /sysdig-chart/values.yaml)
DOCKER_PASSWORD=$(yq -r .airgapped_registry_password /sysdig-chart/values.yaml)

# This function assumes the images have been extracted
# from the uber tar and are available locally.
function push_images() {
  docker login -u "$DOCKER_USERNAME" -p "$DOCKER_PASSWORD" "$DOCKER_REGISTRY"

  for image in $(yq -r '.spec.template.spec | {containers: .containers[]?}.containers.image' /manifests/generated/*.yaml); do
    img=${image#*/}
    if [[ -z $(docker images -qa "$image") ]]; then
      logger info "Docker image '$image' not found locally pulling it"
      docker pull "$image"
    fi
    docker tag {quay.io,"$DOCKER_REGISTRY"}/"$img"
    docker push "$DOCKER_REGISTRY"/"$img"
  done
}

function create_uber_tar() {

  "${TEMPLATE_DIR}"/generate_templates.sh -f "${TEMPLATE_DIR}"/uber_config/values.yaml
  rm -f sysdig_configurator.tar.gz
  local configurator_image
  local tmp_dir

  tmp_dir=$(mktemp -d)
  configurator_image=${1}

  (
    cd "$tmp_dir"
    docker tag "$configurator_image" configurator
    docker save configurator -o configurator.tar.gz
    for image in $(yq -r '.spec.template.spec | {containers: .containers[]?}.containers.image' /manifests/generated/*.yaml); do
      img_without_path=${image##*/}

      if [[ -z $(docker images -q "$image") ]]; then
        logger info "Pulling $image"
        docker pull "$image"
      fi

      logger info "Saving $image as ${img_without_path}.tar.gz"
      docker save "$image" -o "${img_without_path}.tar.gz"
    done
  )

# Credit https://www.linuxjournal.com/node/1005818
(
	cat <<"EOM"
#!/bin/bash -x
set -euo pipefail
echo ""
echo "Sysdig Airgap install"
echo ""

IMAGE_ARCHIVE=images_archive
mkdir "$IMAGE_ARCHIVE"

ARCHIVE=`awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' $0`

tail -n+$ARCHIVE $0 | tar xzv -C "$IMAGE_ARCHIVE"

CDIR=$(pwd)
cd "$IMAGE_ARCHIVE"

for tar in $(find . -type f -name *.gz); do
  file_without_tar=${tar%.tar.gz}
  img_without_path=${file_without_tar##*/}
	docker load -i "${tar}"
done

cd $CDIR
rm -rf "$IMAGE_ARCHIVE"

if [[ -z ${NO_RUN:-} ]]; then
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v ~/.kube:/root/.kube -v "$CDIR":/manifests configurator
fi
exit 0

__ARCHIVE_BELOW__
EOM
) > sysdig_configurator.tar.gz

  tar -cvzf bin.tar "$tmp_dir"
  cat bin.tar >> sysdig_configurator.tar.gz
  chmod +x sysdig_configurator.tar.gz
}

function append_airgap_docker_config() {
  local airgap_docker_config
  airgap_docker_config=$(kubectl create secret docker-registry \
  sysdigcloud-pull-secret --docker-server="$DOCKER_REGISTRY" \
  --docker-username="$DOCKER_USERNAME" \
  --docker-password="$DOCKER_PASSWORD" \
  --dry-run -o json | jq '.data[".dockerconfigjson"]')
  echo airgappullsecret: "$airgap_docker_config" >> /sysdig-chart/values.yaml
}

if [[ ${1:-} == "append_airgap_docker_config" ]]; then
  append_airgap_docker_config
elif [[ ${1:-} == "create_uber_tar" ]]; then
  configurator_image=${2:-}
  create_uber_tar "${configurator_image}"
else
  push_images
fi
