# Datastores as external Kubernetes services

Is it possible to use one or more external datastore services, to configure a non Kubernetes managed service edit the following paramenters in the user setting configMap:

```
mysql.endpoint: <DNS/IP>
cassandra.endpoint: <DNS/IP>
redis.endpoint: <DNS/IP>
```
#### MySQL notes:
MySQL service requires a pre-existing db schema named draios and character-set and collation configured to UTF-8