# Sysdig Cloud on Kubernetes

## Installation Guide

### Requirements

- Running Kubernetes cluster, kubernetes version >= 1.3.X (this guide has been tested with kuberntes 1.3.6)
- Sysdig Cloud quay.io pull secret
- Sysdig Cloud license

### Infrastructure Overview

![Sysdig Cloud infrastructure](images/sysdig_cloud_infrastructure.png?raw=true "Infrastructure")

### Step 1: Namespace creation

It is recommended to create a separate Kubernetes namespace for Sysdig Cloud. The installation manifests don't assume a specific one in order to give the user more flexibility. In the rest of this guide, the chosen namespace will be `sysdigcloud`:

```
kubectl create namespace sysdigcloud
```

### Step 2: User settings

The file `sysdigcloud/config.yaml` contains a ConfigMap all the available user settings, edit the file with the proper settings (the most important of which being the Sysdig Cloud license) and then create the Kubernetes object:

```
kubectl create -f sysdigcloud/config.yaml --namespace sysdigcloud
``` 

### Step 3: Quay pull secret

To download Sysdig Cloud Docker images it is mandatory to create a Kubernetes pull secret. Edit the file `sysdigcloud/pull-secret.yaml` and change the place holder `<PULL_SECRET>` with the provided pull secret.
Create the pull secret object using kubectl:

```
kubectl create -f sysdigcloud/pull-secret.yaml --namespace sysdigcloud
```

### Step 4: SSL certificates

Sysdig Cloud api and collector services use SSL to secure the communication between the customer browser and sysdigcloud agents.

If you want to use a custom SSL secrets, make sure to obtain the respective `server.crt` and `server.key` files, otherwise you can also create a self-signed certificate with:

Create an SSL certificate and deploy it using kubectl:

```
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -subj "/C=US/ST=CA/L=SanFrancisco/O=ICT/CN=onprem.sysdigcloud.com" -keyout server.key -out server.crt
```

Once done, configure a Kubernetes secrets:

```
kubectl create secret tls sysdigcloud-ssl-secret --cert=server.crt --key=server.key --namespace=sysdigcloud
```

### Step 5: Datastore deployment

Sysdig Cloud requires MySQL, Cassandra and Redis to properly work. Deployment of stateful services in Kubernetes can happen in several way, it is recommended to tweak the deployment of those depending on the individual needs. Some offered examples are:

- [Kubernetes pod](datastores/as_kubernetes_pods): easiest method, useful for test deployments
- [Kubernetes pod with persistentVolume](datastores/using_persistent_volumes): robust method, useful for fault tolerance environment where data persistence is critical
- [External service not running in the same Kubernetes cluster](datastores/k8s_external_services): more flexible method, giving full control to the user about the location and deployment of the datastores

### Step 6: Expose Sysdig Cloud services

To access Sysdig Cloud api and collector services you can create a Kubernetes `nodePort` or `LoadBalacer` type, depending on the specific needs.

#### NodePort

Using the NodePort type the Kubernetes master will allocate a port on each Node and will proxy that port (the same port number on every Node) into your service.

It is possible to create a NodePort Service for sysdigcloud api and collector using kubectl and the templates in the sysdigcloud directory:

```
kubectl create -f sysdigcloud/api-nodeport-service.yaml -f sysdigcloud/collector-nodeport-service.yaml --namespace sysdigcloud
```

#### LoadBalancer

On cloud providers which support external load balancers, using a "LoadBalancer" will provision a load balancer for your Service. The actual creation of the load balancer happens asynchronously. Traffic from the external load balancer will be directed at the backend Pods, though exactly how that works depends on the cloud provider.

It is possible to create a LoadBalancer Service for sysdigcloud api and collector using kubectl and the templates in the sysdigcloud folder:

```
kubectl create -f sysdigcloud/api-loadbalancer-service.yaml -f sysdigcloud/collector-loadbalancer-service.yaml --namespace sysdigcloud
```

### Step 7: Deploy Sysdig Cloud components

The Sysdig Cloud tiers can be created with the proper manifests:

```
kubectl create -f sysdigcloud/sdc-api.yaml -f sysdigcloud/sdc-collector.yaml -f sysdigcloud/sdc-worker.yaml --namespace sysdigcloud
```

This command will create three deployments named `sysdigcloud-api`, `sysdigcloud-collector`, `sysdigcloud-worker`

### Step 8: Connect to Sysdig Cloud

After all the components have been deployed, it should be possible to continue the installation by opening the browser on the port exposed by the `sysdigcloud-api` service (the specific port depends on the chosen service type).

# Additional topics

## Release pinning

By default, the manifests use the `latest` tag of the Sysdig Cloud Docker images. This means that every time a new pod is created (e.g. scaling activity) the latest stable version of Sysdig Cloud will be pulled and installed. This is not always the desired behavior, so if the user wants to pin the installation to a specific version, that's possible by changing the deployment and setting an alternative tag. For example, to pin a Sysdig Cloud installation to version 353:

```
kubectl set image deployment/sysdigcloud-api api=quay.io/sysdig/sysdigcloud-backend:353 --namespace sysdigcloud
kubectl set image deployment/sysdigcloud-collector collector=quay.io/sysdig/sysdigcloud-backend:353 --namespace sysdigcloud
kubectl set image deployment/sysdigcloud-worker worker=quay.io/sysdig/sysdigcloud-backend:353 --namespace sysdigcloud
```

## Updates

Sysdig Cloud releases are listed [here](https://github.com/draios/sysdigcloud-kubernetes/releases). Each release has a version number (e.g. 353) and upgrade notes. For the majority of the updates, new manifests will not change, and so the update process is as simple as doing a restart of the Sysdig Cloud deployments if the image in the manifest is pointing to the `latest` tag:

```
kubectl patch deployment sysdigcloud-api -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}" --namespace sysdigcloud
kubectl patch deployment sysdigcloud-collector -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}" --namespace sysdigcloud
kubectl patch deployment sysdigcloud-worker -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}" --namespace sysdigcloud
```

If, instead, the user relied on the release pinning, the upgrade will be as simple as bumping the image of the deployments, as listed in the previous section.

In some circumstances, the manifests will change, the typical case being new parameters added to the ConfigMap, or some parameters in the deployment templates will be modified. In these cases, the upgrade notes will clearly indicate what changed. In most cases, the easiest thing to do will be to recreate the ConfigMap and the Deployments. Several strategies can be adopted to minimize the downtime.

Although updating to the latest release is recommended, this repository is easily versioned, and a customer can feel free to stay to a particular release, and will always be able to fetch the specific manifests navigating the specific release.

## Scale components

For performance and high availability reasons, it is possible to scale the Sysdig Cloud api, collector and worker by changing the number of replicas on the respective deployments:

```
kubectl --namespace sysdigcloud scale --replicas=2 deployment sysdigcloud-collector --namespace sysdigcloud
kubectl --namespace sysdigcloud scale --replicas=2 deployment sysdigcloud-worker --namespace sysdigcloud
kubectl --namespace sysdigcloud scale --replicas=2 deployment sysdigcloud-api --namespace sysdigcloud
```

It is also recommended to scale the Cassandra cluster (the procedure depends on the type of Cassandra deployment, follow the specific guides for more information).

## Configuration changes

To change the original installation parameters, the ConfigMap can simply be edited:

```
kubectl edit configmap/sysdigcloud-config --namespace sysdigcloud
```

After updating the ConfigMap, the Sysdig Cloud components need to be restarted in order for the changed to take effect. This can be done by simply forcing a rolling update of the deployments:

```
kubectl patch deployment sysdigcloud-api -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}" --namespace sysdigcloud
kubectl patch deployment sysdigcloud-collector -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}" --namespace sysdigcloud
kubectl patch deployment sysdigcloud-worker -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}" --namespace sysdigcloud
```

## Troubleshooting data

When experiencing issues, you can collect troubleshooting data that can help the support team. The data can be collected by hand, or we provide a very simple `get_support_bundle.sh` script that takes as an argument the namespace where Sysdig Cloud is deployed and will generate a tarball containing some information (mostly log files):

```
$ ./get_support_bundle.sh sysdigcloud
Getting support logs for sysdigcloud-api-1477528018-4od59
Getting support logs for sysdigcloud-api-1477528018-ach89
Getting support logs for sysdigcloud-cassandra-2987866586-fgcm8
Getting support logs for sysdigcloud-collector-2526360198-e58uy
Getting support logs for sysdigcloud-collector-2526360198-v1egg
Getting support logs for sysdigcloud-mysql-2388886613-a8a12
Getting support logs for sysdigcloud-redis-1701952711-ezg8q
Getting support logs for sysdigcloud-worker-1086626503-4cio9
Getting support logs for sysdigcloud-worker-1086626503-sdtrc
Support bundle generated: 1473897425_sysdig_cloud_support_bundle.tgz
```
