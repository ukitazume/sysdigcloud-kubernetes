# Sysdig onprem configurator.

Configurator is a collection of scripts to automate the deployment of
sysdigcloud.

## Development requirements

- [Docker](https://docs.docker.com/install/)
- [Make](https://www.gnu.org/software/make/), this is optional you can read
the [Makefile](Makefile) and run the commands in the target by hand instead.

## Building the image

```bash
$> make build
```

this will build and tag a configurator docker image, to override the image/tag
name, set the environment variable `IMAGE_NAME`, e.g:

```bash
IMAGE_NAME=my_awesome_image:my_awesome_tag make build
```

## Testing

```bash
$> make test
```

## Development workflow

- Make your changes
- If you are introducing a new configuration type that will generate extra
yaml code, do the below:
  - copy one of the directories in
  [sysdig-chart/tests/resources](sysdig-chart/tests/resources)
  - modify the values.yaml
  - Run `make config_gen`, this should produce a new `sysdig.json` file,
  commit this along with your changes.
- Run tests `make test`
- If there are diff failures, run `make config_gen`

The rationale for the workflow is it helps the code reviewers to see the
effect(s) of the changes introduced, it also helps exercise the config
generation workflow.

## Usage

### Quickstart

- Login to quay.io
  - Retrieve quay username and password from quaypullsecret, e.g:
  ```bash
  AUTH=$(echo <REPLACE_WITH_quaypullsecret> | base64 -d | jq -r '.auths."quay.io".auth'| base64 -d)
  QUAY_USERNAME=${AUTH%:*}
  QUAY_PASSWORD=${AUTH#*:}
  ```
  - Use QUAY_USERNAME and QUAY_PASSWORD retrieved from previous step to login
  to quay
  ```bash
  docker login -u "$QUAY_USERNAME" -p "$QUAY_PASSWORD" quay.io
  ```
- Copy [sysdig-chart/values.yaml](sysdig-chart/values.yaml) to your
working directory, you can do:
```bash
wget \
https://raw.githubusercontent.com/draios/sysdigcloud-kubernetes/5c56fcd96fe0ef602413f9c05f3a54427e14303b/configurator/sysdig-chart/values.yaml
```
- Update the `size`, `quaypullsecret`, `storageClassProvisioner`,
`sysdig.agentCount`, `sysdig.license` and `sysdig.dnsName`.  See [full
configuration](configuration.md) for all possible configuration options.
- Run
```bash
docker run -v ~/.kube:/root/.kube -v $(pwd):/manifests \
  quay.io/sysdig/configurator:2.3.0-1.0.0
```

### Configuration

See [full configuration](configuration.md) for all possible configuration
options.

### Non-Airgap deployment

This assumes the Kubernetes cluster has network access to pulling images from
quay.io.

NB: Configurator will generate
[imagePullSecrets](https://kubernetes.io/docs/concepts/containers/images/#specifying-imagepullsecrets-on-a-pod),
so you do not have to worry about authenticated access to quay.io.

#### Requirements for installation machine

- Network access to Kubernetes cluster
- Docker
- Edited [sysdig-chart/values.yaml](sysdig-chart/values.yaml) 

#### Workflow

- Login to quay.io
  - Retrieve quay username and password from quaypullsecret, e.g:
  ```bash
  AUTH=$(echo <REPLACE_WITH_quaypullsecret> | base64 -d | jq -r '.auths."quay.io".auth'| base64 -d)
  QUAY_USERNAME=${AUTH%:*}
  QUAY_PASSWORD=${AUTH#*:}
  ```
  - Use QUAY_USERNAME and QUAY_PASSWORD retrieved from previous step to login
  to quay
  ```bash
  docker login -u "$QUAY_USERNAME" -p "$QUAY_PASSWORD" quay.io
  ```
- Copy [sysdig-chart/values.yaml](sysdig-chart/values.yaml) to your
working directory, you can do:
```bash
wget \
https://raw.githubusercontent.com/draios/sysdigcloud-kubernetes/5c56fcd96fe0ef602413f9c05f3a54427e14303b/configurator/sysdig-chart/values.yaml
```
- Modify the values.yaml
- Run
```bash
docker run -v ~/.kube:/root/.kube -v $(PWD):/manifests \
  quay.io/sysdig/configurator:2.3.0-1.0.0
```

### Airgap installation with installation machine multi-homed

This assumes a private docker registry is used and the installation machine
has network access to pull from quay.io and push images to the private
registry.

#### Requirements for installation machine

- Network access to Kubernetes cluster
- Docker
- Bash
- [jq](https://stedolan.github.io/jq/)
- Network access to quay.io
- Network and authenticated access to the private registry
- Edited [sysdig-chart/values.yaml](sysdig-chart/values.yaml), with airgap
registry details updated

#### Workflow

- Login to quay.io
  - Retrieve quay username and password from quaypullsecret, e.g:
  ```bash
  AUTH=$(echo <REPLACE_WITH_quaypullsecret> | base64 -d | jq -r '.auths."quay.io".auth'| base64 -d)
  QUAY_USERNAME=${AUTH%:*}
  QUAY_PASSWORD=${AUTH#*:}
  ```
  - Use QUAY_USERNAME and QUAY_PASSWORD retrieved from previous step to login
  to quay
  ```bash
  docker login -u "$QUAY_USERNAME" -p "$QUAY_PASSWORD" quay.io
  ```
- Copy [sysdig-chart/values.yaml](sysdig-chart/values.yaml) to your
working directory, you can do:
```bash
wget \
https://raw.githubusercontent.com/draios/sysdigcloud-kubernetes/5c56fcd96fe0ef602413f9c05f3a54427e14303b/configurator/sysdig-chart/values.yaml
```
- Modify the values.yaml
- Run
```bash
docker run -v ~/.kube:/root/.kube -v $(PWD):/manifests \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ~/.docker:/root/docker \
  quay.io/sysdig/configurator:2.3.0-1.0.0
```

### Full Airgap installation

This assumes a private docker registry is used and the installation machine
does not have network access to pull from quay.io, but can push images to the
private registry. In this situation a machine with network access will be used
to pull an image that contains self extracting tarball that can be copied to
the installation machine, we will call this machine jump machine.

#### Requirements for jump machine

- Network access to quay.io
- Docker
- [jq](https://stedolan.github.io/jq/)

#### Requirements for installation machine

- Network access to Kubernetes cluster
- Docker
- Bash
- [tar](https://linux.die.net/man/1/tar)
- Network and authenticated access to the private registry
- Edited [sysdig-chart/values.yaml](sysdig-chart/values.yaml), with airgap
registry details updated

#### Workflow

**On Jump Machine**
- Login to quay.io
  - Retrieve quay username and password from quaypullsecret, e.g:
  ```bash
  AUTH=$(echo <REPLACE_WITH_quaypullsecret> | base64 -d | jq -r '.auths."quay.io".auth'| base64 -d)
  QUAY_USERNAME=${AUTH%:*}
  QUAY_PASSWORD=${AUTH#*:}
  ```
  - Use QUAY_USERNAME and QUAY_PASSWORD retrieved from previous step to login
  to quay
  ```bash
  docker login -u "$QUAY_USERNAME" -p "$QUAY_PASSWORD" quay.io
  ```
- Pull image containing self-extracting tar:
```bash
docker pull quay.io/sysdig/configurator:2.3.0-1.0.0-uber
```
- Extract the tarball:
```bash
docker create --name uber_image quay.io/sysdig/configurator:2.3.0-1.0.0-uber
docker cp uber_image:/sysdig_configurator.tar.gz .
docker rm uber_image
```
- Copy the tarball to the installation machine

**On the installation machine**

- Copy [sysdig-chart/values.yaml](sysdig-chart/values.yaml) to your
working directory, you can do:
```bash
wget \
https://raw.githubusercontent.com/draios/sysdigcloud-kubernetes/5c56fcd96fe0ef602413f9c05f3a54427e14303b/configurator/sysdig-chart/values.yaml
```
- Modify the values.yaml
- Copy the tar file to the directory
- Run the tar file `bash sysdig_configurator.tar.gz`

### Local Storage

When `local` storage is selected, configurator uses
https://github.com/kubernetes-sigs/sig-storage-local-static-provisioner to
manage creation of persistent volumes. Requirement for this to work is that
volumes are created and mounted under the directory `/sysdig`, e.g:

```bash
tree /sysdig/
/sysdig/
├── vol1
├── vol2
└── vol3
```

on every node in the cluster. Below is an example of creating such volumes
using a [`loop device`](https://en.wikipedia.org/wiki/Loop_device):

```bash
parallel-ssh -t 0 --inline-stdout -l admin -x "-o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null -t" -h \
  <(kubectl get nodes --selector='!node-role.kubernetes.io/master' -o json | \
  jq -r '.items[].status.addresses[] | select (.type == \
  "ExternalIP").address') \
  "sudo bash -c ' \
    for i in \$(seq 1 3); do \
      mkdir -p /sysdig/vol\${i}; \
      dd if=/dev/zero of=/vol\${i} bs=1024 count=35000000; \
      mkfs.ext4 /vol\${i}; \
      mount /vol\${i} /sysdig/vol\${i}; \
    done \
  '"
```

The above creates 3 35G volumes per Kubernetes node. _Use the above as a last
resort and prefer creating raw volumes_. Volume requirements for a default
setup are as below:

Cluster size | Minimum Volume Size | Minimum number of volumes|
|-----|----|---|
small | 35G | 4|
medium | 110G | 8|
large | 320G | 14|

Minimum number of volumes is determined by `cassandraReplicaCount` +
`elasticSearchReplicaCount` + 2. If those are configured, ensure the number of
created volumes is greater than or equal to the new sum.
