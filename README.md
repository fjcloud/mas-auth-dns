# MAS auth to the in-cluster router

Manage calls the public auth route. On an internal load balancer that preserves the client IP, the call hangs when Manage and a router are on the same node.

Pods keep the public name. This Deployment answers it with the router Service address. CoreDNS only forwards that one name.

```bash
export ROUTER=$(oc get svc router-default -n openshift-ingress -o jsonpath='{.spec.clusterIP}')
export AUTH=$(oc get route -A -o jsonpath='{range .items[?(@.spec.to.name=="coreidp")]}{.spec.host}{"\n"}{end}' | head -n1)
export MINOR=$(oc get clusterversion version -o jsonpath='{.status.desired.version}' | cut -d. -f1,2)
echo "$ROUTER  $AUTH  v$MINOR"
```

```bash
oc new-app -f https://raw.githubusercontent.com/fjcloud/mas-auth-dns/main/template.yaml \
  -p AUTH_HOST="$AUTH" \
  -p ROUTER_IP="$ROUTER" \
  -p IMAGE="registry.redhat.io/openshift4/ose-coredns-rhel9:v${MINOR}"
```

```bash
IP=$(oc get svc auth-dns -n auth-dns -o jsonpath='{.spec.clusterIP}')
oc patch dns.operator default --type=merge -p '{"spec":{"servers":[{"name":"mas-auth","zones":["'"$AUTH"'"],"forwardPlugin":{"policy":"Sequential","upstreams":["'"$IP:5353"'"]}}]}}'
oc delete pod -n openshift-dns -l dns.operator.openshift.io/daemonset-dns=default
```

`AUTH_HOST` and `ROUTER_IP` are the container environment. The image tag is `v` plus the cluster minor, from `registry.redhat.io`.

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
oc delete namespace auth-dns
```
