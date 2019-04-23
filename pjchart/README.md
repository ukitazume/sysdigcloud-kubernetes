MISSION - TEMPLATE for the win

Inputs:

1.  Dns
2.  Namespace
3.  Quay secret
4.  Sysdig license
5.  Passwords - cassy mysql redis es
6.  Overlay - small medium large
7.  Agents - collect count - to get replica counts
8.  Certs - tls certs, java certs
9.  Flavor - k8s, openshift, GKE
10. Product - monitor, monitor+secure

Adding Marks inputs
#machines #of nodes, cpu/mem/disk
#replicas - pods #cassy #elastic

values.yaml contains all the variables

helm template --values values.yaml --output-dir manifests/ .
