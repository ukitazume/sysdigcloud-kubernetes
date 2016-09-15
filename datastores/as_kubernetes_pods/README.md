# Datastores as Kubernetes pod
Sysdig Cloud datastores can be deployed as simple kubernetes pods that uses local volumes.
Using local volumes is not reccomended for production deployment because the data is persisted only for the duration of pod life.

create the datastores using the definitions present in the manifests subfolder:
```
kubectl create -f manifests/mysql.yaml -f manifests/cassandra.yaml -f manifests/redis.yaml
```