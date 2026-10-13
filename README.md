# MAS auth to the in-cluster router

## Create the project

```bash
oc new-project auth-dns
```

## Router and hostname

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

## Build the resolver

```bash
oc new-app https://github.com/fjcloud/mas-auth-dns \
  --env MASHOST="$AUTH" \
  --env ROUTER_IP="$ROUTER"
```

## Forward the auth name

```bash
IP=$(
  oc get svc mas-auth-dns -n auth-dns \
    -o jsonpath='{.spec.clusterIP}'
)
NS=$(
  POD=$(oc get pod -n openshift-dns \
    -l dns.operator.openshift.io/daemonset-dns=default \
    -o jsonpath='{.items[0].metadata.name}')
  oc exec -n openshift-dns "$POD" -c dns -- \
    awk '/^nameserver / {print $2":53"; exit}' /etc/resolv.conf
)
echo "fallback: $NS"
oc patch dns.operator default --type=merge -p "$(cat <<EOF
{
  "spec": {
    "servers": [{
      "name": "mas-auth",
      "zones": ["${AUTH}"],
      "forwardPlugin": {
        "policy": "Sequential",
        "upstreams": ["${IP}:5353", "${NS}"]
      }
    }]
  }
}
EOF
)"
```

## Restart CoreDNS

```bash
oc delete pod -n openshift-dns \
  -l dns.operator.openshift.io/daemonset-dns=default
```

## Check

```bash
oc exec -n auth-dns deploy/mas-auth-dns \
  -- getent hosts "$AUTH"
```

## Remove

### Drop the forward

```bash
oc patch dns.operator default --type=json -p \
  '[{"op":"remove","path":"/spec/servers"}]'
```

### Restart CoreDNS

```bash
oc delete pod -n openshift-dns \
  -l dns.operator.openshift.io/daemonset-dns=default
```

### Delete the project

```bash
oc delete project auth-dns
```
