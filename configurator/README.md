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

## Releasing

### Versioning

The Configurator versioning scheme is as below:

<sysdig_platform_version>-<monotonous integer>

The integer starts at 1 and is bumped for every release of the configurator,
then reset to 1 for a release of sysdig_platform_version. E.g:

For the first release of configurator the release of sysdig platform is
`2.3.0`, hence the configurator version is `2.3.0-1` next release of
configurator for this sysdig platform is `2.3.0-2`, if a new sysdig platform
is released tomorrow as `2.3.1` a new release of configurator will be cut at
`2.3.1-1`.

For uber images containing a tarball of all images for [airgap
installations](#full-airgap-installation) the versioning scheme is:

<configurator_version>-uber

For release candidates the version is:

<next_configurator_version>-rc-<JENKINS_BUILD_NUMBER>

### Release Candidates

On every successful build of the main branch, Jenkins tags a release candidate
version matching `<next_release_tag>-rc<$JENKINS_BUILD_NUMBER>` and pushes
the git tag, and a docker image matching the git tag.

### Full Release

The workflow for doing a full (non-rc) release is as below:

- Change `configurator/next_version` to the new tag to be released, for
example if the new tag is `2.3.0-2`, do as below:
```bash
echo -n 2.3.0-2 > next_version
```
- Commit the change, e.g: `git commit -am 'Bumping version to 2.3.0-2'`
- Push the change: `git push`
- Submit a PR and get the PR merged
- Wait for Jenkins to complete build of the main branch including your last
commit.
- Request that no one merges to the main branch till you are done releasing.
- Once Jenkins is done building and has pushed the docker image and git tag,
checkout to the last release candidate tag built by Jenkins, e.g:
```bash
git checkout 2.3.0-2-rc${REPLACE_WITH_JENKINS_BUILD_NUMBER}
```
- Read the diff of changes from the last release
```bash
git diff $(cat configurator/current_version)..
```
- Create a new release tag, e.g:
```bash
git tag -F <(git log --oneline $(cat configurator/current_version)..) $(cat configurator/next_version)
git push origin refs/tags/"$(cat configurator/next_version)"
```
- Go the Jenkins UI and click the build now button for the new tag (this will
not be necessary when we move to the new Jenkins).
- Wait for the Jenkins build for the new tag to complete successfully.
- Update every part of the README.md(this file) that indicates a version to
indicate the latest release tag.
- Update the internal wiki instructions pointing at the latest release.
- Update `configurator/current_version` to reflect the new tag, e.g:
```
cat configurator/next_version > configurator/current_version
```
- Increment the number after the hypen e.g `1` in `2.3.0-2` by `1` and update
the `configurator/next_version` file, this is hypothetically the next future
version, e.g:
```bash
echo -n 2.3.0-3 > configurator/next_version
```
- Commit the changes
```bash
git commit -am "Tagged 2.3.0-2"
```
- Push the change and submit a PR.

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
https://raw.githubusercontent.com/draios/sysdigcloud-kubernetes/5b91dbf0e783d880ddf17f83b76881d2e61af96c/configurator/sysdig-chart/values.yaml
```
- Update the `size`, `quaypullsecret`, `storageClassProvisioner`,
`sysdig.agentCount`, `sysdig.license` and `sysdig.dnsName`.  See [full
configuration](configuration.md) for all possible configuration options.
- Run
```bash
docker run -v ~/.kube:/root/.kube -v $(pwd):/manifests \
  quay.io/sysdig/configurator:2.3.0-1
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
https://raw.githubusercontent.com/draios/sysdigcloud-kubernetes/5b91dbf0e783d880ddf17f83b76881d2e61af96c/configurator/sysdig-chart/values.yaml
```
- Modify the values.yaml
- Run
```bash
docker run -v ~/.kube:/root/.kube -v $(PWD):/manifests \
  quay.io/sysdig/configurator:2.3.0-1
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
https://raw.githubusercontent.com/draios/sysdigcloud-kubernetes/5b91dbf0e783d880ddf17f83b76881d2e61af96c/configurator/sysdig-chart/values.yaml
```
- Modify the values.yaml
- Run
```bash
docker run -v ~/.kube:/root/.kube -v $(PWD):/manifests \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ~/.docker:/root/docker \
  quay.io/sysdig/configurator:2.3.0-1
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
docker pull quay.io/sysdig/configurator:2.3.0-1-uber
```
- Extract the tarball:
```bash
docker create --name uber_image quay.io/sysdig/configurator:2.3.0-1-uber
docker cp uber_image:/sysdig_configurator.tar.gz .
docker rm uber_image
```
- Copy the tarball to the installation machine

**On the installation machine**

- Copy [sysdig-chart/values.yaml](sysdig-chart/values.yaml) to your
working directory, you can do:
```bash
wget \
https://raw.githubusercontent.com/draios/sysdigcloud-kubernetes/5b91dbf0e783d880ddf17f83b76881d2e61af96c/configurator/sysdig-chart/values.yaml
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
