Required parameters are in bold letters.

Parameter | Description | Options | Default|
|---------|-------------|---------|--------|
**schema_version** | This represents the schema version of the values.yaml configuration, it follows semver and maintain server guarantees around versioning | - | `1.0.0` |
**size** | Size of the cluster.<br>This defines CPU & Memory & Disk & Replicas | `small\|medium\|large` | - |
**quaypullsecret** | quaypullsecret provided by the marketing team that kubelet will use to pull sysdigcloud images from Quay | - | - |
**storageClassProvisioner** | name of [storage class provisioner](https://kubernetes.io/docs/concepts/storage/storage-classes/#provisioner) to use when creating the configured `storageClassName` parameter. `hostPath` or `local` should be used in clusters that do not have a provisioner however `local` should be preferred over `hostPath` see [local storage](README.md#local-storage) for instructions on setting it up | `aws\|gke\|hostPath\|local` | - |
**sysdig.agentCount** | number of sysdig agents to deploy | - | - |
**sysdig.license** | sysdig license as provided by the marketing team | - | - |
**sysdig.dnsName** | Domain name the sysdig api will be served on| - | - |
sysdig.admin.username | Sysdig Platform super admin user. This will be used for initial login to the web interface. | - | `test@sysdig.com` |
sysdig.admin.password | Sysdig Platform super admin password. This along with `sysdig.admin.username` will be used for initial login to the web interface. It is auto-generated when not explicitly configured | - | Auto-generated 16 random alphanumeric characters. |
scripts | defines which scripts needs to be run<br> generate - performs templating & kustomization<br>deploy - applies the generated script in k8s environment| `generate\|deploy\|generate deploy`| `generate deploy` |
apps | defines applications needed. |`monitor\|monitor secure` | `monitor secure` |
namespace | namespace to deploy sysdigcloud in | - | `sysdig` |
storageClassName | name of preconfigured [storage class](https://kubernetes.io/docs/concepts/storage/storage-classes/), if the storage class does not exist configurator will attempt to create it, using the `storageClassProvisioner` as the provisioner | - | `sysdig` |
localStoragehostDir | Path on the host where local volumes are mounted under. | - | `/sysdig` |
nodeaffinityLabel.key | key of the label used to configure the nodes sysdig cloud pods are expected to run on, the nodes are expected to have been labeled with the key | - | - |
nodeaffinityLabel.value | value of the label used to configure the nodes sysdig cloud pods are expected to run on, the nodes are expected to have been labeled with the value as value to `nodeaffinityLabel.key`, required if `nodeaffinityLabel.key` is configured  | - | - |
cloudProvider.name| Name of the cloud provider | `aws\|gke` | - |
cloudProvider.isMultiAZ | If the cluster is deployed in multiple availability zones requires `cloudProvider.name` to be configured| `true\|false` | `false` |
cloudProvider.region | Region the cluster is deployed in e.g: `us-east-1`, required if `cloudProvider.name` is configured| - | - |
cloudProvider.create_loadbalancer | when set to true a service of type [`LoadBalancer`](https://kubernetes.io/docs/concepts/services-networking/#loadbalancer) is created| `true|false` | `false` |
airgapped_registry_name | URL of the airgapped (internal) docker registry, this is used for installations where the Kubernetes cluster can not pull images directly from quay, see [airgap instructions multi-homed](README.md#airgap-installation-with-installation-machine-multi-homed) and [full airgap instructions](README.md#full-airgap-installation) for more details | - | - |
airgapped_registry_username | username for the configured `airgapped_registry_name`, if the registry does not require authentication you can ignore this | - | - |
airgapped_registry_password | password for the configured `airgapped_registry_username` user, if the registry does not require authentication you can ignore this | - | - |
deployment | Name of Kubernetes installation | `openshift\|kubernetes` | `kubernetes` |
sysdig.certificate.generate | This determines if configurator should generate self-signed certificates for the domain configured in `sysdig.dnsName` | `true\|false` | `true` |
sysdig.certificate.crt | Path(the path must be in same directory as `values.yaml` file and must be relative to `values.yaml`) to user provided certificate that will be used in serving the sysdig api, if `sysdig.certificate.generate` is set to `false` this has to be configured. The certificate common name or subject altername name must match configured sysdig.dnsName | - | - |
sysdig.certificate.key | Path(the path must be in same directory as `values.yaml` file and must be relative to `values.yaml`) to user provided key that will be used in serving the sysdig api, if `sysdig.certificate.generate` is set to `false` this has to be configured. The key must match the certificate in `sysdig.certificate.crt`| - | - |
sysdig.collector.dnsName | Domain name the sysdig collector will be served on, when not configured it defaults to whatever is configured for `sysdig.dnsName` | - | Value of `sysdig.dnsName` |
sysdig.collector.certificate.generate | This determines if configurator should generate self-signed certificates for the domain configured in `sysdig.collector.dnsName` | `true\|false` | `true` |
sysdig.collector.certificate.crt | Path(the path must be in same directory as `values.yaml` file and must be relative to `values.yaml`) to user provided certificate that will be used in serving the sysdig collector, if `sysdig.collector.certificate.generate` is set to `false` this has to be configured. The certificate common name or subject altername name must match configured sysdig.collector.dnsName | - | - |
sysdig.collector.certificate.key | Path(the path must be in same directory as `values.yaml` file and must be relative to `values.yaml`) to user provided key that will be used in serving the sysdig collector, if `sysdig.collector.certificate.generate` is set to `false` this has to be configured. The key must match the certificate in `sysdig.collector.certificate.crt`| - | - |
sysdig.cassandraReplicaCount | Number of cassandra replicas, this is a noop for small clusters| - | small cluster: 1<br>medium cluster: 3<br>large cluster: 6|
sysdig.elasticSearchReplicaCount | Number of elasticsearch replicas, this is a noop for small clusters| - | small cluster: 1<br>medium cluster: 3<br>large cluster: 6|
sysdig.apiReplicaCount | Number of sysdig api replicas, this is a noop for small clusters| - | small cluster: 1<br>medium cluster: 3<br>large cluster: 5|
sysdig.collectorReplicaCount | Number of sysdig collector replicas, this is a noop for small clusters| - | small cluster: 1<br>medium cluster: 3<br>large cluster: 5|
sysdig.workerReplicaCount | Number of sysdig worker replicas, this is a noop for small clusters| - | small cluster: 1<br>medium cluster: 3<br>large cluster: 5|
sysdig.redisHa | determines if redis should run in HA mode| `true\|false` | `false`|
sysdig.smtpServer | specifies smtp server to use to send email| - | - |
sysdig.smtpServerPort | specifies port for the configured smtp server| `1-65535` | `25` |
sysdig.smtpUser | specifies user for the configured smtp server| - | - |
sysdig.smtpPassword | specifies password for the configured smtp user| - | - |
sysdig.smtpProtocolTLS | specifies if TLS should be used for smtp| `true\|false` | - |
sysdig.smtpProtocolSSL | specifies if SSL should be used for smtp| `true\|false` | - |
sysdig.smtpFromAddress | specifies the email address for the FROM field of sent emails| - | - |
sysdig.openshiftUrl | specifies openshift api url with port number, this is required if `deployment` is `openshift` | - | - |
sysdig.openshiftUser | specifies openshift username, this is required if `deployment` is `openshift` | - | - |
sysdig.openshiftPassword | specifies openshift password, this is required if `deployment` is `openshift` | - | - |
sysdig.collectorPort | sepecify alternative collector port | `1024-65535` | `6443` |
sysdig.customCa | expects certs/custom-ca.pem in manifets folder, adds it to java's trusted list | - | - |
sysdig.monitorVersion | Version of the sysdig monitor | - | `2.3.0.2461` |
sysdig.anchoreVersion | Version of the sysdig anchore | - | `v0.4.1.1` |
sysdig.cassandraVersion | Version of Cassandra run by sysdig cloud | - | `2.1.21.13` |
sysdig.elasticsearchVersion | Version of ElasticSearch run by sysdig cloud | - | `5.6.16.5` |
sysdig.mysqlVersion | Version of mysql run by sysdig cloud | - | `5.6.44.0` |
sysdig.postgresVersion | Version of PostgreSQL run by sysdig cloud | - | `10.6.10` |
sysdig.redisVersion | Version of Redis run by sysdig cloud | - | `4.0.12.5` |
sysdig.redisHaVersion | Version of HA Redis run by sysdig cloud | - | `4.0.12.5-ha` |
sysdig.haproxyVersion | Version of HAProxy run by sysdig cloud | - | `v0.7-beta.7` |
sysdig.rsyslogVersion | Version of rsyslog run by sysdig cloud | - | `8.34.0.5` |
sysdig.localVolumeProvisioner | Version of localVolumeProvisioner run by sysdig cloud | - | `v2.3.2` |
elasticsearch.searchguard.enabled | Enables user authentication and TLS-encrypted data-in-transit with [Searchguard](https://search-guard.com/) | `true \| false` | `true` |
elasticsearch.searchguard.adminUser | The user bound to the ElasticSearch Searchguard admin role | - | `sysdig` |
elasticsearch.jvmOptions | - | - | - |
hostPathCustomPaths.cassandra | Directory to bind mount cassandra pod's `/var/lib/cassandra` to on the host, this is only relevant when storageClassProvisioner is `hostPath` | - | `/var/lib/cassandra` |
hostPathCustomPaths.elasticsearch | Directory to bind mount elasticsearch pod's `/usr/share/elasticsearch` to on the host, this is only relevant when storageClassProvisioner is `hostPath` | - | `/usr/share/elasticsearch` |
hostPathCustomPaths.mysql | Directory to bind mount mysql pod's `/var/lib/mysql` to on the host, this is only relevant when storageClassProvisioner is `hostPath` | - | `/var/lib/mysql` |
hostPathCustomPaths.postgresql | Directory to bind mount postgresql pod's `/var/lib/postgresql/data/pgdata` to on the host, this is only relevant when storageClassProvisioner is `hostPath` | - | `/var/lib/postgresql/data/pgdata` |
pvStorageSize.small.cassandra | Size of the persistent volume assigned to cassandra in a cluster of `size` small, this option is ignored if `storageClassProvisioner` is `hostPath` | - | `30Gi` |
pvStorageSize.small.elasticsearch | Size of the persistent volume assigned to elasticsearch in a cluster of `size` small, this option is ignored if `storageClassProvisioner` is `hostPath` | - | `30Gi` |
pvStorageSize.small.mysql | Size of the persistent volume assigned to mysql in a cluster of `size` small, this option is ignored if `storageClassProvisioner` is `hostPath` | - | `25Gi` |
pvStorageSize.small.postgresql | Size of the persistent volume assigned to postgresql in a cluster of `size` small, this option is ignored if `storageClassProvisioner` is `hostPath` | - | `30Gi` |
pvStorageSize.medium.cassandra | Size of the persistent volume assigned to cassandra in a cluster of `size` medium, this option is ignored if `storageClassProvisioner` is `hostPath` | - | `100Gi` |
pvStorageSize.medium.elasticsearch | Size of the persistent volume assigned to elasticsearch in a cluster of `size` medium, this option is ignored if `storageClassProvisioner` is `hostPath` | - | `100Gi` |
pvStorageSize.medium.mysql | Size of the persistent volume assigned to mysql in a cluster of `size` medium, this option is ignored if `storageClassProvisioner` is `hostPath` | - | `25Gi` |
pvStorageSize.medium.postgresql | Size of the persistent volume assigned to postgresql in a cluster of `size` medium, this option is ignored if `storageClassProvisioner` is `hostPath` | - | `60Gi` |
pvStorageSize.large.cassandra | Size of the persistent volume assigned to cassandra in a cluster of `size` large, this option is ignored if `storageClassProvisioner` is `hostPath` | - | `300Gi` |
pvStorageSize.large.elasticsearch | Size of the persistent volume assigned to elasticsearch in a cluster of `size` large, this option is ignored if `storageClassProvisioner` is `hostPath` | - | `300Gi` |
pvStorageSize.large.mysql | Size of the persistent volume assigned to mysql in a cluster of `size` large, this option is ignored if `storageClassProvisioner` is `hostPath` | - | `25Gi` |
pvStorageSize.large.postgresql | Size of the persistent volume assigned to postgresql in a cluster of `size` large, this option is ignored if `storageClassProvisioner` is `hostPath` | - | `60Gi` |
