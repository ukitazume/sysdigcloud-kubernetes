# Generating Certs for Search Guard
Make sure that `elasticsearch.searchguard.enabled` is set to "true" in `sysdigcloud/config.yaml`
Set `elasticsearch.user` to the searchguard role that the elasticsearch cluster will be using

**Roles**

There are currently only 2 roles that SG has set up:
- **admin**: Has access to everything in the cluster and all indices
- **readonly**: Can only read indices and access monitoring endpoints for the cluster (Ex. Health)

**Steps**

1. Run the following docker command to generate the root/admin certs to a directory of your choice
`docker run -d -it -v "$(pwd)"/out:/usr/share/elasticsearch/tools/out quay.io/sysdig/elasticsearch:sg-certs-1.0`
2. Generate the required kubernetes secret file 
`kubectl -n <my-namespace> create secret generic ca-certs --from-file=out`
3. Generate the password secrets for the admin/readonly searchguard roles
`kubectl -n <my-namespace> create secret generic sg-admin-secret --from-literal=password='<admin-password-here>'`
`kubectl -n <my-namespace> create secret generic sg-readonly-secret --from-literal=password='<readonly-password-here>'`

**Search Guard config files**

The current configuration contains only the 2 roles mentioned above. If you would like to add more roles/personalize the configuration further, you can edit the files under the `sgconfig` directory before creating the secret. Once you are satisfied with the configuration, run the following command:

`kubectl -n <my-namespace> create secret generic sg-config-files --from-file=sgconfig`
