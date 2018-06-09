# sdc-kubernetes: Sysdig Cloud Monitor Backend on Kubernetes


## Table of Contents
  * [What is this?](#What-is-this?)
  * [Infrastructure Overview](#Infrastructure-Overview)
  * [Requirements](#Requirements)
  * [Installation Guide](#Installation-Guide)
  * [Confirm Installation](#Confirm-Installation)
  * [What does the installer do?](#What-does-the-installer-do?)
  * [Operations Guide](#Operations-Guide)
      - [Stop and Start](#Stop-and-Start)
      - [Scale up and down](#scale-up-and-down)
      - [Modifying configMap](#Modifying-configMap)
      - [Version updates](#Version-updates)
      - [Uninstall](#Uninstall)
  * [Tips and Tricks](#Tips-and-Tricks)


## What is this? <a id="What-is-this?"></a>

SDC-Kubernetes is an on-prem version of [Sysdig Monitor](https://sysdig.com/product/monitor/), a SAAS offering by Sysdig 
Inc for monitoring containerized and non-containerized environments. 
The official on-prem Kubernetes guide can be found [here](https://github.com/draios/sysdigcloud-kubernetes). 

Here are the most recent updates:

- **Introduction of Statefulsets**
    
    **NOTE**: Kubernetes statefulsets are stable (GA) in version 1.9. Using an earlier version may have adverse affects.

- **Introduction of persistence to datastores**

    Persistent volumes can utilize block disks from the various cloud provider dynamically. The disks can be encrypted, 
    adjusted for IOPS specific performance and can utilize snapshots for backups.
    
- **Elimination of single points of failure**

    All datastore components are now highly-available running in statefulsets with replicas >= 3. Cassandra and 
    Elasticsearch comprise of active/active cluster rings. MySQL and Redis are configured master/slave replications.
    In general, when a new Pod joins the set as a slave, it must assume the MySQL master might already have data on it. 
    It also must assume that the replication logs might not go all the way back to the beginning of time. These 
    conservative assumptions are the key to allow a running StatefulSet to scale up and down over time, rather than 
    being fixed at its initial size.
    The second Init Container, named clone-mysql, performs a clone operation on a slave Pod the first time it starts 
    up on an empty PersistentVolume. That means it copies all existing data from another running Pod, so its local state 
    is consistent enough to begin replicating from the master.
    MySQL itself does not provide a mechanism to do this, so the example uses a popular open-source tool called Percona 
    XtraBackup. During the clone, the source MySQL server might suffer reduced performance. To minimize impact on the 
    MySQL master, the script instructs each Pod to clone from the Pod whose ordinal index is one lower. This works 
    because the StatefulSet controller always ensures Pod N is Ready before starting Pod N+1. Please note that it is 
    advised to allow 2X the disk size for MySQL.


- **Templatize Deployment**

  SDC-settings.yaml contains configurable parameters.
  Templates in $SDC_HOME/etc/config/templates will be populated by variables contained in the sdc-settings file and 
  manifests are created
  
## Infrastructure Overview <a id="Infrastructure-Overview"></a>

![sdc-kubernetes](https://user-images.githubusercontent.com/12384605/32736470-653dabb8-c84c-11e7-89bb-71c201ec980f.png?raw=true)

###### Backend Components
* api-servers: Provides a web and API interface to the sysdig application
* collectors: Agents connect to the backend via sysdig collectors
* workers: Process data aggregations and alerts

###### Cache Layer
* redis: intra-service cache

###### DataStores
* mysql: stores user data and environmental data
* elasticsearch: stores event and metadata
* cassandra: stores sysdig metrics

Backend components (worker, api and collector) are stateless deployed in deploymentsets.
Datastores (redis, mysql, elasticsearch and cassandra) are stateful. They are configured in statefulsets that use 
Persistent Volume Claims (PVC) from the cloud provider.

## Requirements <a id="Requirements"></a>

- Access to a running Kubernetes cluster on AWS or GKE.
- Sysdig Cloud quay.io pull secret
- Sysdig Cloud license
- kubectl installed on your machine and communicating with the Kubernetes cluster
- [kontemplate] (https://github.com/tazjin/kontemplate) is required for templatize deployment.

## Installation Guide <a id="Installation-Guide"></a>

1. Clone the repository
    `git clone https://github.com/draios/sysdigcloud-kubernetes.git`
2. Edit the file `etc/config/sdc-settings.yaml`. This file contains the editable parameter.
3. Next is to run `/bin/create-manfiests.sh`. This wiull build the Kubernetes manifests.
4. Finally, run `/bin/install.sh` to install and run the application.  


## Confirm Installation  <a id="Confirm-Installation"></a>

Once the installation has been completed, your output should look similar (please note that the below output is an example):
    
    $ kubectl get pods -n sysdigcloud    
    sdc-api-2039094698-11rtd         1/1       Running   0          13m
    sdc-cassandra-0                  1/1       Running   0          12m
    sdc-cassandra-1                  1/1       Running   0          11m
    sdc-cassandra-2                  1/1       Running   0          11m
    sdc-collector-1001165270-chrz0   1/1       Running   0          13m
    sdc-elasticsearch-0              1/1       Running   0          14m
    sdc-elasticsearch-1              1/1       Running   0          14m
    sdc-elasticsearch-2              1/1       Running   0          14m
    sdc-mysql-0                      2/2       Running   0          14m
    sdc-mysql-slave-0                2/2       Running   1          14m
    sdc-mysql-slave-1                2/2       Running   0          14m
    sdc-redis-0                      1/1       Running   0          14m
    sdc-redis-slave-0                1/1       Running   0          14m
    sdc-redis-slave-1                1/1       Running   0          14m
    sdc-worker-1937471472-hfp25      1/1       Running   0          13m

    $ kubectl -n sysdigcloud get services
    NAME                CLUSTER-IP   EXTERNAL-IP        PORT(S)                               AGE
    sdc-api             10.3.0.36    ad0d03112c706...   443:32253/TCP                         32m
    sdc-cassandra       None         <none>             9042/TCP,7000/TCP,7001/TCP,7199/TCP   34m
    sdc-collector       10.3.0.203   ad0e5cf87c706...   6443:31063/TCP                        32m
    sdc-elasticsearch   None         <none>             9200/TCP,9300/TCP                     34m
    sdc-mysql           None         <none>             3306/TCP                              34m
    sdc-mysql-slave     None         <none>             3306/TCP                              33m
    sdc-redis           None         <none>             6379/TCP,16379/TCP                    34m
    sdc-redis-slave     None         <none>             6379/TCP,16379/TCP                    34m

Describe the sdc-api service to get the full API endpoint URL.
It will be `ad0d03112c70611e79d6006e5a830746-1802392156.us-west-1.elb.amazonaws.com` in this case. Use this URL to 
access the SDC Monitor interface. This URL can be given a sensible URL via Route53 or similar.
(please note that the below output is an example)

    $ kubectl -n sysdigcloud describe service sdc-api
    Name:            sdc-api
    Namespace:       sysdigcloud
    Labels:          app=sysdigcloud
                     role=api
    Annotations:     <none>
    Selector:        app=sysdigcloud,role=api
    Type:            LoadBalancer
    IP:              10.3.0.36
    LoadBalancer Ingress:    ad0d03112c70611e79d6006e5a830746-1802392156.us-west-1.elb.amazonaws.com
    Port:            secure-api    443/TCP
    NodePort:        secure-api    32253/TCP
    Endpoints:        10.2.79.173:443
    Session Affinity:    None
    Events:
      FirstSeen    LastSeen    Count    From            SubObjectPath    Type        Reason            Message
      ---------    --------    -----    ----            -------------    --------    ------            -------
      33m        33m        1    service-controller            Normal        CreatingLoadBalancer    Creating load balancer
      33m        33m        1    service-controller            Normal        CreatedLoadBalancer     Created load balancer


Describe the sdc-collector service to see the full collector endpoint URL. It will be `ad0e5cf87c70611e79d6006e5a830746-257288196.us-west-1.elb.amazonaws.com`
(please note that the below output is an example)

    $ kubectl -n sysdigcloud describe service sdc-collector
    Name:            sdc-collector
    Namespace:       sysdigcloud
    Labels:          app=sysdigcloud
                     role=collector
    Annotations:     <none>
    Selector:        app=sysdigcloud,role=collector
    Type:            LoadBalancer
    IP:              10.3.0.203
    LoadBalancer Ingress:    ad0e5cf87c70611e79d6006e5a830746-257288196.us-west-1.elb.amazonaws.com
    Port:            secure-collector    6443/TCP
    NodePort:        secure-collector    31063/TCP
    Endpoints:        10.2.23.211:6443
    Session Affinity:    None
    Events:
      FirstSeen    LastSeen    Count    From            SubObjectPath    Type        Reason            Message
      ---------    --------    -----    ----            -------------    --------    ------            -------
      34m        34m        1    service-controller            Normal        CreatingLoadBalancer    Creating load balancer
      33m        33m        1    service-controller            Normal        CreatedLoadBalancer     Created load balancer


In the above example, go to `https://ad0d03112c70611e79d6006e5a830746-1802392156.us-west-1.elb.amazonaws.com:<port#>` to 
access the main Monitor GUI.
Point your collectors to `ad0e5cf87c70611e79d6006e5a830746-257288196.us-west-1.elb.amazonaws.com`.



## What does the installer do? <a id="What-does-the-installer-do?"></a>

1. It creates a namespace called *sysdigcloud* where all components are deployed.

    `kubectl create namespace sysdigcloud`

2. It creates Kubernetes secrets and configMaps populated with information about usernames, passwords, ssl certs, 
quay.io pull secret and various application specific parameters.

    `kubectl create -f etc/sdc-config.yaml`

3. Create Kubernetes StorageClasses identifying the types of disks to be provided to our datastores.

    `kubectl create -R -f datastores/storageclasses/`

4. Creates the datastore statefulsets (redis, mysql, elasticsearch and cassandra). Elasticsearch and Cassandra are 
automatically setup with --replica=3 generating full clusters. Redis and mysql are configured with master/slave replication. 

    `kubectl create -R -f datastores/`

5. Deploys the backend Deployment sets (worker, collect and api)

    `kubectl create -R -f backend/`

## Operations Guide <a id="Operations-Guide"></a>

#### Stop and Start <a id="Stop-and-Start"></a>

You can stop the whole application by running `uninstall.sh`. It will save the namespace, storageclasses and PVC's. 
You can then start the application with `install.sh`. Script will complain about pre-existing elements, but the application 
will still be started. PVC's are preserved which means all data on redis, mysql, elasticsearch and cassandra are persisted. 
If you want to start with application with clean PVC's, either uninstall the application as described in the "Uninstall section" or delete PVC's manually after shutting down applications. 

You can also stop and start individual components:

###### Shutdown all backend components using the definition yaml files
```
$ pwd
~/sdc-kubernetes/aws

$ kubectl -n sysdigcloud -R -f backend/
service "sdc-api" deleted
deployment "sdc-api" deleted
service "sdc-collector" deleted
deployment "sdc-collector" deleted
deployment "sdc-worker" deleted
```

###### Shutdown Cassandra using the yaml file
```
$ kubectl -n sysdigcloud delete -f datastore/sdc-cassandra.yaml
service "sdc-cassandra" deleted
statefulset "sdc-cassandra" deleted
```

###### Shutdown Elasticsearch and associated service
```
$ kubectl -n sysdigcloud get statefulsets 
NAME                DESIRED   CURRENT   AGE
sdc-elasticsearch   3         3         2d
sdc-mysql           1         1         2d
sdc-mysql-slave     3         3         2d
sdc-redis           1         1         2d
sdc-redis-slave     2         2         2d

$ kubectl -n sysdigcloud delete statefulset sdc-elasticsearch
statefulset "sdc-elasticsearch" deleted

$ kubectl -n sysdigcloud get services
NAME                CLUSTER-IP   EXTERNAL-IP   PORT(S)              AGE
sdc-elasticsearch   None         <none>        9200/TCP,9300/TCP    2d
sdc-mysql           None         <none>        3306/TCP             2d
sdc-mysql-slave     None         <none>        3306/TCP             2d
sdc-redis           None         <none>        6379/TCP,16379/TCP   2d
sdc-redis-slave     None         <none>        6379/TCP,16379/TCP   2d

$ kubectl -n sysdigcloud delete service sdc-elasticsearch
service "sdc-elasticsearch" deleted
```

###### Start Components individually
```
$ pwd
~/sdc-kubernetes/aws

$ kubectl create -f etc/sdc-config.yaml
$ kubectl create -f datastores/sdc-mysql-master.yaml 
$ kubectl create -f datastores/sdc-mysql-slaves.yaml 
$ kubectl create -f datastores/sdc-redis-master.yaml 
$ kubectl create -f datastores/sdc-redis-slaves.yaml 
$ kubectl create -f datastores/sdc-cassandra.yaml  
$ kubectl create -f datastores/sdc-elasticsearch.yaml 
$ kubectl create -f backend/sdc-api.yaml
$ kubectl create -f backend/sdc-colector.yaml
$ kubectl create -f backend/sdc-worker.yaml

```

#### Scale up and down <a id="Scale-up-and-down"></a>

You can scale up and down any sdc-kubernetes component. 

For worker, collector and api which are deployed as Deployment sets, do:
```
$kubectl -n sysdigcloud scale --replicas=5 deployment sdc-api
$kubectl -n sysdigcloud scale --replicas=5 deployment sdc-collector
$kubectl -n sysdigcloud scale --replicas=5 deployment sdc-worker

$ for i in sdc-api sdc-collector sdc-worker; do kubectl -n sysdigcloud --replicas=1 $i; done
```

For the datastores, redis, mysql, elasticsearch and cassandra, which are deployed as Statefulsets, do:
```
#scale up or down depending on existing number of copies
$kubectl -n sysdigcloud scale --replicas=4 statefulset sdc-cassandra
$kubectl -n sysdigcloud scale --replicas=4 statefulset sdc-elasticsearch
$kubectl -n sysdigcloud scale --replicas=4 statefulset sdc-mysql-slave
$kubectl -n sysdigcloud scale --replicas=4 statefulset sdc-redis-slave
```

You can edit a particular configMap:
`kubectl -n sysdigcloud edit configmap sysdigcloud-config`

The preferred method would be to edit the file `etc/sdc-config.yaml` and replace the whole configMap set
```
vi etc/sdc-config.yaml
kubectl -n sysdigcloud replace configmap -f etc/sdc-config.yaml
```

After updating the ConfigMap, the Sysdig Cloud components need to be restarted in order for the changed parameters to 
take effect. This can be done by simply forcing a rolling update of the deployments. A possible way to do so is:

```
kubectl patch deployment sdc-api -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}" -n sysdigcloud
kubectl patch deployment sdc-collector -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}" -n sysdigcloud
kubectl patch deployment sdc-worker -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}" -n sysdigcloud
```

This will ensure that the application restarts with no downtime (assuming the deployments have more than one replica each).


#### Version updates <a id="Version-updates"></a>

Sysdig Cloud releases are listed [here](https://github.com/draios/sysdigcloud-kubernetes/releases). Each release has a 
version number (e.g. 893) and specific upgrade notes. If you look in the 3 backend files `backend/sdc-api.yaml`, `backend/sdc-collector.yaml` and `backend/sdc-worker.yaml`, you will see the following identical line in all of them under their container/image defintions:
```
image: quay.io/sysdig/sysdigcloud-backend:658
```
In this case, we are running version 658 of the backend. 

To upgrade to version 893 (the latest), there are two options:

1. Edit the backend files' yaml definitions. Add the right tag for the image `sysdigcloud-backend` like:
```
image: quay.io/sysdig/sysdigcloud-backend:658
```
and restart the app.

2. You can do a rolling update if downtimes are sensitive.
```
kubectl set image deployment/sdc-api api=quay.io/sysdig/sysdigcloud-backend:893 -n sysdigcloud
kubectl set image deployment/sdc-collector collector=quay.io/sysdig/sysdigcloud-backend:893 -n sysdigcloud
kubectl set image deployment/sdc-worker worker=quay.io/sysdig/sysdigcloud-backend:893 -n sysdigcloud
```

#### Uninstall <a id="Uninstall"></a>

To completely remove the sdc-kubernetes application, run the following commands
```
uninstall.sh
```
This will shutdown all components and by destorying the namespace, it will destroy the PVC's.
  