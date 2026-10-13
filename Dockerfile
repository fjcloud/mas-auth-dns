FROM registry.redhat.io/openshift4/ose-coredns-rhel9:v4.22
COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh
EXPOSE 5353/tcp
EXPOSE 5353/udp
ENTRYPOINT ["/entrypoint.sh"]
