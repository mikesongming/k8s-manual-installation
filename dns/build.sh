#!/bin/bash

source ../env.sh

__SOURCE_FILENAME__=kube-dns.yaml.base
SERVICE_CIDR=${SERVICE_CIDR/\//\\\/}

cat > transforms2sed.sed <<EOF
s/__PILLAR__DNS__SERVER__/$CLUSTER_DNS_SVC_IP/g
s/__PILLAR__DNS__DOMAIN__/$CLUSTER_DNS_DOMAIN/g
s/__PILLAR__CLUSTER_CIDR__/"${SERVICE_CIDR}"/g
s/__MACHINE_GENERATED_WARNING__/Warning: This is a file generated from the base underscore template file: $__SOURCE_FILENAME__/g
EOF

sed -f transforms2sed.sed kube-dns.yaml.base > kube-dns.yaml
