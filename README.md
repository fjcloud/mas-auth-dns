# MAS auth to the in-cluster router

Manage calls the public auth hostname. These commands make pods resolve that name to the router Service, so the call does not go through the ingress load balancer.

```bash
export ROUTER=$(oc get svc router-default -n openshift-ingress -o jsonpath='{.spec.clusterIP}')
export AUTH=$(oc get route -A -o jsonpath='{range .items[?(@.spec.to.name=="coreidp")]}{.spec.host}{"\n"}{end}' | head -n1)
```

```bash
oc new-app https://github.com/fjcloud/mas-auth-dns --env MASHOST="$AUTH" --env ROUTER_IP="$ROUTER"
```

```bash
IP=$(oc get svc mas-auth-dns -o jsonpath='{.spec.clusterIP}')
oc patch dns.operator default --type=merge -p '{"spec":{"servers":[{"name":"mas-auth","zones":["'"$AUTH"'"],"forwardPlugin":{"policy":"Sequential","upstreams":["'"$IP:5353"'"]}}]}}'
oc delete pod -n openshift-dns -l dns.operator.openshift.io/daemonset-dns=default
```

`new-app` runs in the current project and creates Service `mas-auth-dns` on port 5353. The patch forwards only the auth name. CoreDNS does not load that change until its pods are deleted.

Remove:

```bash
oc patch dns.operator default --type=json -p '[{"op":"remove","path":"/spec/servers"}]'
oc delete pod -n openshift-dns -l dns.operator.openshift.io/daemonset-dns=default
oc delete all -l app=mas-auth-dns
```
