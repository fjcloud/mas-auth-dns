# MAS auth to the in-cluster router

Manage calls the public auth hostname. These commands make pods resolve that name to the router Service, so the call does not go through the ingress load balancer.

Create the project and switch to it.

```bash
oc new-project auth-dns
```

Read the router Service address and the auth route hostname, then print both.

```bash
export ROUTER=$(
  oc get svc router-default -n openshift-ingress \
    -o jsonpath='{.spec.clusterIP}'
)
export AUTH=$(
  oc get route -A \
    -o jsonpath='{range .items[?(@.spec.to.name=="coreidp")]}{.spec.host}{"\n"}{end}' \
    | head -n1
)
echo "route hostname: $AUTH"
echo "router ip: $ROUTER"
```

Build the resolver in this project. `MASHOST` and `ROUTER_IP` are the container environment.

```bash
oc new-app https://github.com/fjcloud/mas-auth-dns \
  --env MASHOST="$AUTH" \
  --env ROUTER_IP="$ROUTER"
```

Forward only the auth name to Service `mas-auth-dns` port 5353.

```bash
IP=$(
  oc get svc mas-auth-dns -n auth-dns \
    -o jsonpath='{.spec.clusterIP}'
)
oc patch dns.operator default --type=merge -p "$(cat <<EOF
{
  "spec": {
    "servers": [{
      "name": "mas-auth",
      "zones": ["${AUTH}"],
      "forwardPlugin": {
        "policy": "Sequential",
        "upstreams": ["${IP}:5353"]
      }
    }]
  }
}
EOF
)"
```

Restart CoreDNS. The operator writes the Corefile but does not reload the running pods.

```bash
oc delete pod -n openshift-dns \
  -l dns.operator.openshift.io/daemonset-dns=default
```

Remove:

Drop the auth forward from cluster DNS.

```bash
oc patch dns.operator default --type=json -p \
  '[{"op":"remove","path":"/spec/servers"}]'
```

Restart CoreDNS so it stops using the forward.

```bash
oc delete pod -n openshift-dns \
  -l dns.operator.openshift.io/daemonset-dns=default
```

Delete the project.

```bash
oc delete project auth-dns
```
