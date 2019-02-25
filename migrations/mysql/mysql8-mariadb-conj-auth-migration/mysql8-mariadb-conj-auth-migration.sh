#!/bin/bash

echo "Sysdig MySQL to MariaDB Connector Migration Tool"

# Default YAML definition
k8s_yaml_text_default="
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: sysdigcloud
    role: mysql8-mariadb-conj-auth-migration
  name: sysdig-mysql8-mariadb-conj-auth-migration
spec:
  restartPolicy: Never
  containers:
    - name: mysql8-mariadb-conj-auth-migration
      image: quay.io/sysdig/onprem_migration:mysql8-mariadb-conj-auth-migration-1.0.0
      env:
        - name: MYSQL_HOST
          valueFrom:
            configMapKeyRef:
              name: sysdigcloud-config
              key: mysql.endpoint
        - name: MYSQL_PORT
          value: \"3306\"
        - name: MYSQL_ROOT_USER
          value: \"root\"
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            configMapKeyRef:
              name: sysdigcloud-config
              key: mysql.password
        - name: SYSDIG_ADMIN_USER
          valueFrom:
            configMapKeyRef:
              name: sysdigcloud-config
              key: mysql.user
        - name: SYSDIG_ADMIN_PASSWORD
          valueFrom:
            configMapKeyRef:
              name: sysdigcloud-config
              key: mysql.password
"

# Try to perform the migration with the default YAML
echo "$k8s_yaml_text_default" > mysql8-mariadb-conj-auth-migration.yaml
kubectl -n sysdigcloud create -f mysql8-mariadb-conj-auth-migration.yaml >/dev/null
while true; do
  status=$(kubectl -n sysdigcloud describe pods sysdig-mysql8-mariadb-conj-auth-migration | grep "Status:[ \t]*")
  is_running=$(echo $status | grep "Pending\|Running")
  if [ -z "$is_running" ]; then break; fi;
done

is_succeeded=$(echo $status | grep Succeeded)

# Default YAML success, exit the script
if [ -n "$is_succeeded" ]; then
  # Print the logs
  kubectl -n sysdigcloud logs sysdig-mysql8-mariadb-conj-auth-migration
  # Cleanup
  kubectl -n sysdigcloud delete -f mysql8-mariadb-conj-auth-migration.yaml >/dev/null
  rm mysql8-mariadb-conj-auth-migration.yaml
  docker rmi -f quay.io/sysdig/onprem_migration:mysql8-mariadb-conj-auth-migration-1.0.0 >/dev/null
  exit
fi

# If default YAML failed, ask for custom parameters
kubectl -n sysdigcloud delete -f mysql8-mariadb-conj-auth-migration.yaml >/dev/null

echo "Please enter the required values (press Enter for default)"
read -p "Sysdig Kubernetes namespace (default sysdigcloud): " KUBERNETES_NAMESPACE
if [ -z "$KUBERNETES_NAMESPACE" ]; then KUBERNETES_NAMESPACE=sysdigcloud; fi
read -p "MySQL port (default 3306): " MYSQL_PORT
if [ -z "$MYSQL_PORT" ]; then MYSQL_PORT=3306; fi
read -p "MySQL root username (default root): " MYSQL_ROOT_USER
if [ -z "$MYSQL_ROOT_USER" ]; then MYSQL_ROOT_USER=root; fi
read -sp "MySQL root password:" MYSQL_ROOT_PASSWORD
echo

# Custom YAML definition
k8s_yaml_text_custom="
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: sysdigcloud
    role: mysql8-mariadb-conj-auth-migration
  name: sysdig-mysql8-mariadb-conj-auth-migration
spec:
  restartPolicy: Never
  containers:
    - name: mysql8-mariadb-conj-auth-migration
      image: quay.io/sysdig/onprem_migration:mysql8-mariadb-conj-auth-migration-1.0.0
      env:
        - name: MYSQL_HOST
          valueFrom:
            configMapKeyRef:
              name: sysdigcloud-config
              key: mysql.endpoint
        - name: MYSQL_PORT
          value: \"$MYSQL_PORT\"
        - name: MYSQL_ROOT_USER
          value: \"$MYSQL_ROOT_USER\"
        - name: MYSQL_ROOT_PASSWORD
          value: \"$MYSQL_ROOT_PASSWORD\"
        - name: SYSDIG_ADMIN_USER
          valueFrom:
            configMapKeyRef:
              name: sysdigcloud-config
              key: mysql.user
        - name: SYSDIG_ADMIN_PASSWORD
          valueFrom:
            configMapKeyRef:
              name: sysdigcloud-config
              key: mysql.password
"

# Try to perform the migration with the custom YAML
echo "$k8s_yaml_text_custom" > mysql8-mariadb-conj-auth-migration.yaml
kubectl -n $KUBERNETES_NAMESPACE create -f mysql8-mariadb-conj-auth-migration.yaml >/dev/null
while true; do
  status=$(kubectl -n $KUBERNETES_NAMESPACE describe pods sysdig-mysql8-mariadb-conj-auth-migration | grep "Status:[ \t]*")
  is_running=$(echo $status | grep "Pending\|Running")
  if [ -z "$is_running" ]; then break; fi;
done

is_succeeded=$(echo $status | grep Succeeded)

# Print the logs
kubectl -n $KUBERNETES_NAMESPACE logs sysdig-mysql8-mariadb-conj-auth-migration
# Cleanup
kubectl -n $KUBERNETES_NAMESPACE delete -f mysql8-mariadb-conj-auth-migration.yaml >/dev/null
rm mysql8-mariadb-conj-auth-migration.yaml
docker rmi -f quay.io/sysdig/onprem_migration:mysql8-mariadb-conj-auth-migration-1.0.0 >/dev/null

# If failed, inform the user and set the exit code to 1
if [ -z "$is_succeeded" ]; then
  echo Failure: Please run the tool with correct parameters.
  exit 1
fi
