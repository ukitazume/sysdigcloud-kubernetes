FROM alpine:3.9.4

RUN apk add python py-pip jq openssl
RUN pip install yq kubernetes

RUN mkdir -p helm kubernetes/kubernetes-cli openshift
RUN wget https://storage.googleapis.com/kubernetes-helm/helm-v2.14.0-linux-386.tar.gz && tar xvf helm-v2.14.0-linux-386.tar.gz -C helm/ && rm helm-v2.14.0-linux-386.tar.gz
RUN wget https://github.com/kubernetes-sigs/kustomize/releases/download/v2.0.3/kustomize_2.0.3_linux_amd64 -O kubernetes/kustomize
RUN wget https://storage.googleapis.com/kubernetes-release/release/v1.14.0/bin/linux/amd64/kubectl -O kubernetes/kubernetes-cli/kubectl
RUN chmod u+x kubernetes/kustomize kubernetes/kubernetes-cli/kubectl*
RUN export PATH=$PATH:/helm/linux-386/:/kubernetes:/kubernetes/kubernetes-cli
RUN wget https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz && tar xvf openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz -C openshift && rm openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz

ENTRYPOINT /sysdig-chart/install.sh
