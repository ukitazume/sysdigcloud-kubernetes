FROM alpine:3.9.4

RUN apk add bash python py-pip jq openssl ca-certificates \
      && pip install yq \
      && wget https://storage.googleapis.com/kubernetes-helm/helm-v2.14.0-linux-386.tar.gz \
      && tar xvf helm-v2.14.0-linux-386.tar.gz -C /tmp \
      && cp /tmp/linux-386/helm /usr/bin/ \
      && rm helm-v2.14.0-linux-386.tar.gz \
      && wget https://github.com/kubernetes-sigs/kustomize/releases/download/v2.0.3/kustomize_2.0.3_linux_amd64 -O /usr/bin/kustomize \
      && wget https://storage.googleapis.com/kubernetes-release/release/v1.14.0/bin/linux/amd64/kubectl -O /usr/bin/kubectl \
      && chmod u+x /usr/bin/kustomize /usr/bin/kubectl* \
      && wget https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz \
      && tar xvf openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz -C /tmp \
      && echo -e "#!/bin/sh\n/lib/ld-musl-x86_64.so.1 --library-path /lib /usr/bin/oc-bin \$@" > /usr/bin/oc \
      && echo -e "#!/bin/sh\n/lib/ld-musl-x86_64.so.1 --library-path /lib /usr/bin/oc-kubectl-bin \$@" > /usr/bin/oc-kubectl \
      && chmod +x /usr/bin/oc /usr/bin/oc-kubectl \
      && cp /tmp/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit/kubectl /usr/bin/oc-kubectl-bin \
      && cp /tmp/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit/oc /usr/bin/oc-bin \
      && rm -rf openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz /tmp/openshift* linux-386

COPY sysdig-chart /sysdig-chart

ENTRYPOINT /sysdig-chart/install.sh
