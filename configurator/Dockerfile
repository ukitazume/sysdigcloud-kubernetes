FROM python:3.7.4-slim-buster

ENV DEBIAN_FRONTEND noninteractive
ENV LANG C.UTF-8

ENV JAVA_HOME /usr/local/openjdk-11
ENV PATH $JAVA_HOME/bin:$PATH

# https://adoptopenjdk.net/upstream.html
ENV JAVA_VERSION 11.0.3
ENV JAVA_BASE_URL https://github.com/AdoptOpenJDK/openjdk11-upstream-binaries/releases/download/jdk-11.0.3%2B7/OpenJDK11U-
ENV JAVA_URL_VERSION 11.0.3_7

RUN apt-get update \
      && apt-get install -y openssl ca-certificates p11-kit \
      && set -eux; \
      dpkgArch="$(dpkg --print-architecture)"; \
      case "$dpkgArch" in \
        amd64) upstreamArch='x64' ;; \
        arm64) upstreamArch='aarch64' ;; \
        *) echo >&2 "error: unsupported architecture: $dpkgArch" ;; \
      esac; \
      savedAptMark="$(apt-mark showmanual)"; \
      apt-get update; \
      apt-get install -y --no-install-recommends dirmngr gnupg wget; \
      wget -O openjdk.tgz.asc "${JAVA_BASE_URL}${upstreamArch}_linux_${JAVA_URL_VERSION}.tar.gz.sign"; \
      wget -O openjdk.tgz "${JAVA_BASE_URL}${upstreamArch}_linux_${JAVA_URL_VERSION}.tar.gz" --progress=dot:giga; \
      export GNUPGHOME="$(mktemp -d)"; \
      gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys CA5F11C6CE22644D42C6AC4492EF8D39DC13168F; \
      gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys EAC843EBD3EFDB98CC772FADA5CD6035332FA671; \
      gpg --batch --list-sigs --keyid-format 0xLONG CA5F11C6CE22644D42C6AC4492EF8D39DC13168F | grep '0xA5CD6035332FA671' | grep 'Andrew Haley'; \
      gpg --batch --verify openjdk.tgz.asc openjdk.tgz; \
      gpgconf --kill all; \
      rm -rf "$GNUPGHOME"; \
      mkdir -p "$JAVA_HOME"; \
      tar --extract \
        --file openjdk.tgz \
        --directory "$JAVA_HOME" \
        --strip-components 1 \
        --no-same-owner \
      ; \
      rm openjdk.tgz*; \
      apt-mark auto '.*' > /dev/null; \
      [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
      apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
      \
      { \
        echo '#!/usr/bin/env bash'; \
        echo 'set -Eeuo pipefail'; \
        echo 'if ! [ -d "$JAVA_HOME" ]; then echo >&2 "error: missing JAVA_HOME environment variable"; exit 1; fi'; \
        echo 'cacertsFile=; for f in "$JAVA_HOME/lib/security/cacerts" "$JAVA_HOME/jre/lib/security/cacerts"; do if [ -e "$f" ]; then cacertsFile="$f"; break; fi; done'; \
        echo 'if [ -z "$cacertsFile" ] || ! [ -f "$cacertsFile" ]; then echo >&2 "error: failed to find cacerts file in $JAVA_HOME"; exit 1; fi'; \
        echo 'trust extract --overwrite --format=java-cacerts --filter=ca-anchors --purpose=server-auth "$cacertsFile"'; \
      } > /etc/ca-certificates/update.d/docker-openjdk; \
      chmod +x /etc/ca-certificates/update.d/docker-openjdk; \
      /etc/ca-certificates/update.d/docker-openjdk; \
     #https://github.com/docker-library/openjdk/issues/331#issuecomment-498834472
      find "$JAVA_HOME/lib" -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf; \
      ldconfig; \
     #basic smoke test
      javac --version; \
      java --version \

      && apt-get install -y --no-install-recommends jq curl wget \
      && pip install yq \
      && wget https://storage.googleapis.com/kubernetes-helm/helm-v2.14.0-linux-386.tar.gz \
      && wget https://download.docker.com/linux/static/stable/x86_64/docker-18.09.7.tgz \
      && tar xvf docker-18.09.7.tgz \
      && mv docker/docker /usr/bin/ \
      && rm -rf docker* \
      && tar xvf helm-v2.14.0-linux-386.tar.gz -C /tmp \
      && cp /tmp/linux-386/helm /usr/bin/ \
      && rm -rf helm-v2.14.0-linux-386.tar.gz /tmp/linux-386 \
      && wget https://github.com/kubernetes-sigs/kustomize/releases/download/v2.0.3/kustomize_2.0.3_linux_amd64 -O /usr/bin/kustomize \
      && wget https://storage.googleapis.com/kubernetes-release/release/v1.14.0/bin/linux/amd64/kubectl -O /usr/bin/kubectl \
      && chmod u+x /usr/bin/kustomize /usr/bin/kubectl* \
      && wget https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz \
      && tar xvf openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz -C /tmp \
      && cp /tmp/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit/kubectl /usr/bin/oc-kubectl \
      && cp /tmp/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit/oc /usr/bin/oc \
      && rm -rf openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz /tmp/openshift* \
      && wget https://search.maven.org/remotecontent?filepath=com/floragunn/search-guard-tlstool/1.6/search-guard-tlstool-1.6.tar.gz -O search-guard-tlstool-1.6.tar.gz \
      && tar xzvf search-guard-tlstool-1.6.tar.gz \
      && rm search-guard-tlstool-1.6.tar.gz \
      && apt-get remove -y --purge --autoremove wget curl p11-kit ca-certificates gnupg  \
      && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/

COPY sysdig-chart /sysdig-chart

ENTRYPOINT /sysdig-chart/install.sh
