import sys
from kubernetes import client, config

config.load_kube_config()

storageApi = client.StorageV1Api();

storageClasses = storageApi.list_storage_class();

listStorageClassNames = [storageClass.metadata.name for storageClass in storageClasses.items]

if sys.argv[1] in listStorageClassNames:
    sys.exit(0)
else:
    sys.exit(1)