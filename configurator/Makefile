IMAGE_NAME ?= configurator
LOCAL_SCRIPTS := $(shell find $(SOURCEDIR) -name '*.sh' -exec basename {} \;)
CONTAINER_SCRIPTS := $(addprefix /sysdig-chart/, $(LOCAL_SCRIPTS))

build:
	docker build . -t $(IMAGE_NAME)

shellcheck:
	docker run --rm -v $(PWD)/sysdig-chart:/sysdig-chart koalaman/shellcheck \
	--exclude=SC2164,SC1090 -- $(CONTAINER_SCRIPTS)

config_gen: build
	docker run --rm -v $(PWD)/sysdig-chart:/sysdig-chart --entrypoint /sysdig-chart/test.sh $(IMAGE_NAME) config_gen

test: build shellcheck
	docker run --rm --entrypoint /sysdig-chart/test.sh $(IMAGE_NAME)

run: build
	docker run -v $(PWD)/values.yaml $(IMAGE_NAME)
