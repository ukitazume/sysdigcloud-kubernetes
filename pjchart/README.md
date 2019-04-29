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
11. Ability to turn on/off pod antiaffinity

Adding Marks inputs
#machines #of nodes, cpu/mem/disk
#replicas - pods #cassy #elastic

For deliverable1 with inputs frm Mark:
k8s with monitor+secure
overlays - small & large
small - supports 10 agents
  components
   1 node cassandra - statefulset - 10 * 1.5 gig * 1 replica ~= 15gig = 30gig diskspace
   1 node elastic - statefulset - 30gig diskspace
   1 node single node mysql - convert into stateful set
   1 node single node redis
   1 pod api, collector & worker

large - supports 100 agents
  components
  3 node cassandra - 100 * 1.5gig * 3 replicas ~= 450gig
  3 node elastic (scale characterization needs to be done)
  3 node mysql cluster with router
  1 redis ha - sentinel,primary,secondary
  #replicas for api,collector & worker will be decided based on #agents 
 

values.yaml contains the variables

Needs: kustomize & helm - brew install

steps to run:
./generate_templates.sh
