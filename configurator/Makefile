IMAGE_NAME ?= configurator
UBER_IMAGE_NAME ?= uber_configurator
MANIFESTS = "$(PWD)/tmp"
UBER_TAR = "$(MANIFESTS)/uber_archive.tar.gz"
LOCAL_SCRIPTS := $(shell find $(SOURCEDIR) -name '*.sh' -exec basename {} \;)
CONTAINER_SCRIPTS := $(addprefix /sysdig-chart/, $(LOCAL_SCRIPTS))

clean:
	docker rm configurator uber_image || /bin/true

build: clean
	docker build . -t $(IMAGE_NAME)

build_uber_image: build
	docker run -v /var/run/docker.sock:/var/run/docker.sock \
		-v ~/.docker:/root/.docker \
		--name configurator \
		--entrypoint /sysdig-chart/airgap.sh \
		$(IMAGE_NAME) \
		create_uber_tar $(IMAGE_NAME)
	docker cp configurator:/sysdig_configurator.tar.gz .
	docker build -f Dockerfile.uber -t $(UBER_IMAGE_NAME) .
	rm -f sysdig_configurator.tar.gz
	docker rm configurator || /bin/true

shellcheck:
	docker run --rm -v $(PWD)/sysdig-chart:/sysdig-chart koalaman/shellcheck \
		--exclude=SC2164,SC1090 -- $(CONTAINER_SCRIPTS)

config_gen: build
	docker run --rm -v $(PWD)/sysdig-chart:/sysdig-chart --entrypoint \
		/sysdig-chart/test.sh $(IMAGE_NAME) config_gen

test: build shellcheck
	docker run --rm --entrypoint /sysdig-chart/test.sh $(IMAGE_NAME)

test_uber_tar: build_uber_image
	docker create --name uber_image $(UBER_IMAGE_NAME)
	docker cp uber_image:/sysdig_configurator.tar.gz .
	docker run --rm --entrypoint /sysdig-chart/test.sh \
		-v $(PWD):/uber_dir \
		-v /var/run/docker.sock:/var/run/docker.sock \
		$(IMAGE_NAME) uber_tests
	docker rm uber_image || /bin/true
	rm -f sysdig_configurator.tar.gz

push: build
	docker push $(IMAGE_NAME)

push_uber_tar: build_uber_image
	docker push $(UBER_IMAGE_NAME)

run: build
	docker run -v ~/.kube:/root/.kube -v $(PWD):/manifests $(IMAGE_NAME)
