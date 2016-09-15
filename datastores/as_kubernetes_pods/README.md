# Datastores as Kubernetes pod
Sysdig Cloud datastores can be deployed as simple kubernetes pods that uses local volumes.
Using local volumes is not reccomended for production deployment because the data is persisted only for the duration of pod life.

create the datastores using the definitions present in the manifests subfolder:
```
kubectl create -f manifests/mysql.yaml -f manifests/cassandra.yaml -f manifests/redis.yaml --namespace sysdigcloud
```

To expand the Cassandra cluster, you can just scale the number of replicas of the Cassandra deployment. It is important that the replica count is increased by no more than 1 at every scaling activity. After each scaling activity, the status of the cluster can be checked by executing `nodetool status` in one of the Cassandra pods. All the nodes should be listed as `UN` in order for the cluster to be fully up and running.

For example, to scale a Cassandra cluster to 3 nodes:

```
kubectl scale --replicas=3 deployment sysdigcloud-cassandra --namespace sysdigcloud
```

Immediately after the scaling activity, the new pod will be in joining phase:

```
$ kubectl --namespace sysdig exec -it sysdigcloud-cassandra-2987866586-f5kgo -- nodetool status
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
$ kubectl --namespace sysdig exec -it sysdigcloud-cassandra-2987866586-f5kgo -- nodetool status
Datacenter: datacenter1
=======================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address    Load       Tokens  Owns (effective)  Host ID                               Rack
UN  10.52.2.4  1.88 MB    256     34.1%             99121365-4543-4e50-ae6f-a9a9cb720b7c  rack1
UJ  10.52.0.4  14.43 KB   256     34.0%             4b084d81-21f1-45b6-add9-8fbea7392978  rack1
UN  10.52.1.7  917.91 KB  256     31.9%             9a7437e9-890f-477a-99be-3d8042ddd9d5  rack1
```
