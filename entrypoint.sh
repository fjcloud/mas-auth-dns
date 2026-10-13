#!/bin/sh
set -eu
: "${MASHOST:?set MASHOST}"
: "${ROUTER_IP:?set ROUTER_IP}"
cat >/tmp/Corefile <<EOF
${MASHOST}:5353 {
    hosts {
        ${ROUTER_IP} ${MASHOST}
        ttl 30
    }
    errors
}
.:5353 {
    forward . /etc/resolv.conf
    errors
}
EOF
exec coredns -conf /tmp/Corefile
