# Datastores as Kubernetes pod with persistent volumes
Sysdig Cloud datastores can be deployed as Kubernetes pods that uses persistent volumes.
This guide will cover the creation and the setup of AWS EBS and GCE volumes, for other type of Kubernetes persistent volumes refer to: http://kubernetes.io/docs/user-guide/persistent-volumes/#types-of-persistent-volumes

##Setup Cassandra cluster
Volumes dimensions: The best practice is to allocate 1GB of disk space per sysdigcloud agent to connect * Cassandra replication factor (es: 100 agents * RF=3 = 300GB of Cassandra disk space)

#### Create Cassandra service
Using kubectl create the following Cassandra Headless service

```
apiVersion: v1
kind: Service
metadata:
  name: sysdigcloud-cassandra
  labels:
    app: sysdigcloud
    role: cassandra
spec:
  clusterIP: None
  ports:
    - port: 9042
      name: cql
    - port: 7000
      name: intra-node-communication
    - port: 7001
      name: tls-intra-node-communication
  selector:
    app: sysdigcloud
    role: cassandra
```

Repeat the following steps for all the cassandra pod you want to deploy (cassandra cluster dimension), substitute `N` with the cassandra node number.

#### - Create a volume

If you use AWS you can create a volume using the command line `aws ec2 create-volume` or the AWS console.
If you use GCE you can create a volume using the command line `gcloud compute disks create` or the GCE console.

#### - Create a Kubernetes persistent volume
for AWS:
```
kind: PersistentVolume
apiVersion: v1
metadata:
  name: cassandra-pv-N # Cassandra node number
spec:
  capacity:
    storage: <DIM> # Dimension of the created volume
  accessModes:
    - ReadWriteOnce
  awsElasticBlockStore:
    volumeID: <VOL_ID> # EBS volume ID
    fsType: ext4
```
for GCE:
```
kind: PersistentVolume
apiVersion: v1
metadata:
  name: cassandra-pv-N # Cassandra node number
spec:
  capacity:
    storage: <DIM> # Dimension of the created volume
  accessModes:
    - ReadWriteOnce
  gcePersistentDisk:
    pdName: <VOL_NAME> # GCE volume name
    fsType: ext4
```

#### - Create a Kubernetes persistent volume claim
```
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: cassandra-pvc-N # Cassandra node number
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: <DIM> # Dimension of the created volume
```
#### - Deploy a Cassandra node
```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: sysdigcloud-cassandra-N # Cassandra node number
spec:
  replicas: 1
  template:
    metadata:
      labels:
        instance: N # Cassandra node number
        app: sysdigcloud
        role: cassandra
    spec:
      containers:
        - image: quay.io/sysdig/cassandra:2.1
          name: cassandra
          env:
            - name: CASSANDRA_SERVICE
              value: sysdigcloud-cassandra
            - name: CASSANDRA_NUM_SEEDS
              value: "2"
            - name: CASSANDRA_CLUSTER_NAME
              value: sysdigcloud
            - name: JVM_EXTRA_OPTS
              valueFrom:
                configMapKeyRef:
                  name: sysdigcloud-config
                  key: cassandra.jvm.options
          ports:
            - containerPort: 9042
              name: cql
          volumeMounts:
            - mountPath: /var/lib/cassandra
              name: data
      imagePullSecrets:
        - name: sysdigcloud-pull-secret
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: cassandra-pvc-N # Cassandra node number
```

##Setup MySQL
#### - MySQL service and config  
Create the MySQL config object and MySQL service using kubectl:
```
kubectl create -f manifests/mysql-config.yaml -f manifests/mysql-service.yaml --namespace sysdigcloud
```

#### - Create a volume

If you use AWS you can create a volume using the command line `aws ec2 create-volume` or the AWS console.
If you use GCE you can create a volume using the command line `gcloud compute disks create` or the GCE console.

#### - Create a Kubernetes persistent volume
for AWS:
```
kind: PersistentVolume
apiVersion: v1
metadata:
  name: mysql-pv
spec:
  capacity:
    storage: <DIM> # Dimension of the created volume
  accessModes:
    - ReadWriteOnce
  awsElasticBlockStore:
    volumeID: <VOL_ID> # EBS volume ID
    fsType: ext4
```
for GCE:
```
kind: PersistentVolume
apiVersion: v1
metadata:
  name: mysql-pv
spec:
  capacity:
    storage: <DIM> # Dimension of the created volume
  accessModes:
    - ReadWriteOnce
  gcePersistentDisk:
    pdName: <VOL_NAME> # GCE volume name
    fsType: ext4
```
#### - Deploy a MySQL node
```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: sysdigcloud-mysql
spec:
  template:
    metadata:
      labels:
        app: sysdigcloud
        role: mysql
    spec:
      containers:
        - name: mysql
          image: mysql:5.6.25
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                configMapKeyRef:
                  name: sysdigcloud-config
                  key: mysql.password
            - name: MYSQL_USER
              valueFrom:
                configMapKeyRef:
                  name: sysdigcloud-config
                  key: mysql.user
            - name: MYSQL_PASSWORD
              valueFrom:
                configMapKeyRef:
                  name: sysdigcloud-config
                  key: mysql.password
            - name: MYSQL_DATABASE
              value: draios
          ports:
            - containerPort: 3306
          volumeMounts:
            - name: mysql-config
              mountPath: /etc/mysql/my.cnf
              subPath: my.cnf
            - name: data
              mountPath: /var/lib/mysql
      volumes:
        - name: mysql-config
          configMap:
            name: sysdigcloud-mysql-config
        - name: data
          persistentVolumeClaim:
            claimName: mysql-pvc
```

##Setup Redis
Redis doesn't require persistent storage you can simple deploy it with kubectl:
```
kubectl create -f manifests/redis.yaml --namespace sysdigcloud
```