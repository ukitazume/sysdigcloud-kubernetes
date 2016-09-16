# Datastores as Kubernetes pod

Sysdig Cloud datastores can be deployed as simple Kubernetes pods that use local volumes.
Using local volumes is not recommended for production deployments because the data is persisted only for the lifetime of the pod.

To create the datastores with this method:

```
kubectl create -f manifests/mysql.yaml -f manifests/cassandra.yaml -f manifests/redis.yaml --namespace sysdigcloud
```

This will also create a Cassandra cluster of size 1. To expand the Cassandra cluster, you can just scale the number of replicas in the Cassandra deployment. It is important for the replica count to be increased by no more than 1 at every scaling activity, since Cassandra will refuse the joining of a new node in the Cluster if one joining process is already in progress. After each scaling activity, the status of the cluster can be checked by executing `nodetool status` in one of the Cassandra pods. All the Cassandra nodes should be listed as `UN` in order for the cluster to be fully up and running.

For example, to scale a Cassandra cluster to 3 nodes:

```
kubectl scale --replicas=3 deployment sysdigcloud-cassandra --namespace sysdigcloud
```

Immediately after the scaling activity, the new pod will be in joining phase:

```
$ kubectl --namespace sysdigcloud exec -it sysdigcloud-cassandra-2987866586-f5kgo -- nodetool status
Datacenter: datacenter1
=======================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address    Load       Tokens  Owns (effective)  Host ID                               Rack
UN  10.52.2.4  1.88 MB    256     54.4%             99121365-4543-4e50-ae6f-a9a9cb720b7c  rack1
UJ  10.52.0.4  14.43 KB   256     ?                 4b084d81-21f1-45b6-add9-8fbea7392978  rack1
UN  10.52.1.7  917.91 KB  256     45.6%             9a7437e9-890f-477a-99be-3d8042ddd9d5  rack1
```

After the bootstrapping process terminates, the new pod will terminate the joining phase and the cluster will be fully operational:

```
$ kubectl --namespace sysdigcloud exec -it sysdigcloud-cassandra-2987866586-f5kgo -- nodetool status
Datacenter: datacenter1
=======================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address    Load       Tokens  Owns (effective)  Host ID                               Rack
UN  10.52.2.4  1.88 MB    256     34.1%             99121365-4543-4e50-ae6f-a9a9cb720b7c  rack1
UN  10.52.0.4  14.43 KB   256     34.0%             4b084d81-21f1-45b6-add9-8fbea7392978  rack1
UN  10.52.1.7  917.91 KB  256     31.9%             9a7437e9-890f-477a-99be-3d8042ddd9d5  rack1
```

Maintaining a production Cassandra cluster requires some simple but mandatory housekeeping procedures, best described in the official documentation.
