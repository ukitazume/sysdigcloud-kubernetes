# Generating Certs for Search Guard
Make sure that `elasticsearch.searchguard.enabled` is set to "true" in `sysdigcloud/config.yaml`
Set `elasticsearch.user` to the searchguard role that the elasticsearch cluster will be using

**Steps**

1. Run the following docker command to generate the root/admin certs to a directory of your choice
`docker run -d -it -v "$(pwd)"/out:/tools/out quay.io/sysdig/elasticsearch:sg-certs-1.0`
2. Generate the required kubernetes secret file 
`kubectl -n <my-namespace> create secret generic ca-certs --from-file=out`
3. Generate the secret for your searchguard role password
`kubectl -n <my-namespace> create secret generic sg-password-secret --from-literal=password='<your-password-here>'`

**Roles**

There are currently only 2 roles that SG has set up:
- **admin**: Has access to everything in the cluster and all indices
- **readall**: Can only read indices and access monitoring endpoints for the cluster (Ex. Health)

**Search Guard config files**

The current configuration contains only the 2 roles mentioned above. If you would like to add more roles/personalize the configuration further, you can edit the files under the `sgconfig` directory before creating the secret. Once you are satisfied with the configuration, run the following command:

`kubectl -n <my-namespace> create secret generic sg-config-files --from-file=sgconfig`
