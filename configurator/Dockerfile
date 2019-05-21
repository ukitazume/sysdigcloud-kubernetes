FROM alpine:3.9.4

RUN apk add python py-pip jq openssl
RUN pip install yq

RUN mkdir -p helm kubernetes/kubernetes-cli
RUN wget https://storage.googleapis.com/kubernetes-helm/helm-v2.14.0-linux-386.tar.gz && tar xvf helm-v2.14.0-linux-386.tar.gz -C helm/ 
RUN wget https://github.com/kubernetes-sigs/kustomize/releases/download/v2.0.3/kustomize_2.0.3_linux_amd64 -O kubernetes/kustomize
RUN wget https://storage.googleapis.com/kubernetes-release/release/v1.14.0/bin/linux/amd64/kubectl -O kubernetes/kubernetes-cli/kubectl
RUN chmod u+x kubernetes/kustomize kubernetes/kubernetes-cli/kubectl*
RUN export PATH=$PATH:/helm/linux-386/:/kubernetes:/kubernetes/kubernetes-cli
COPY sysdig-chart sysdig-chart

ENTRYPOINT ash
