## Sysdig onprem configurator.

Configurator is a collection of scripts to automate the deployment of
sysdigcloud.

### Development requirements

- [Docker](https://docs.docker.com/install/)
- [Make](https://www.gnu.org/software/make/), this is optional you can read
the [Makefile](Makefile) and run the commands in the target by hand instead.

### Building the image

```bash
$> make build
```

this will build and tag a configurator docker image, to override the image/tag
name, set the environment variable `IMAGE_NAME`, e.g:

```bash
IMAGE_NAME=my_awesome_image:my_awesome_tag make build
```

### Testing

```bash
$> make test
```

### Development workflow

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

### Usage

- Copy [sysdig-chart/values.yaml](sysdig-chart/values.yaml) to your
working directory, you can do:

```bash
wget \
https://raw.githubusercontent.com/draios/sysdigcloud-kubernetes/Templating_k8s_configurations/configurator/sysdig-chart/values.yaml
```

- Modify the values.yaml
- Run `make run`
