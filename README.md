# MAS auth to the in-cluster router

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

`new-app` builds `registry.redhat.io/openshift4/ose-coredns-rhel9:v4.22` and sets `MASHOST` and `ROUTER_IP` on the deployment. The Service `mas-auth-dns` is created in the current project, on port 5353 TCP and UDP.

The last command tells cluster DNS to forward only that auth name to the Service, then restarts CoreDNS so it loads the change.

Check:

```bash
NS=$(oc get pods -A -l mas.ibm.com/appTypeName=ui -o jsonpath='{.items[0].metadata.namespace}')
POD=$(oc get pods -A -l mas.ibm.com/appTypeName=ui -o jsonpath='{.items[0].metadata.name}')
oc exec -n "$NS" "$POD" -c ui -- getent hosts "$AUTH"
```

`getent` prints the router address. A Manage process that already resolved the public address keeps it until that pod restarts.

Remove:

```bash
oc patch dns.operator default --type=json -p '[{"op":"remove","path":"/spec/servers"}]'
oc delete pod -n openshift-dns -l dns.operator.openshift.io/daemonset-dns=default
oc delete all -l app=mas-auth-dns
```
