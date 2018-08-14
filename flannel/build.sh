#!/bin/bash

source ../env.sh

FLANNEL_SYSCONF=/etc/sysconfig/flanneld


cat > k8s.conf <<EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

cp k8s.conf /etc/sysctl.d/
sysctl -p /etc/sysctl.d/k8s.conf


cat > flanneld-csr.json <<EOF
{
    "CN": "flanneld",
        "hosts": [],
        "key": {
            "algo": "rsa",
            "size": 2048
        },
        "names": [
            {
                "C": "CN",
                "ST": "BeiJing",
                "L": "BeiJing",
                "O": "k8s",
                "OU": "System"
            }
        ]
}
EOF

cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
    -ca-key=/etc/kubernetes/ssl/ca-key.pem \
    -config=/etc/kubernetes/ssl/ca-config.json \
    -profile=kubernetes flanneld-csr.json | cfssljson -bare flanneld

mkdir -p /etc/flanneld/ssl
cp flannel*.pem /etc/flanneld/ssl/

etcdctl \
    --endpoints=${ETCD_ENDPOINTS} \
    --ca-file=/etc/kubernetes/ssl/ca.pem \
    --cert-file=/etc/flanneld/ssl/flanneld.pem \
    --key-file=/etc/flanneld/ssl/flanneld-key.pem \
    set ${FLANNEL_ETCD_PREFIX}/config '{"Network":"'${POD_CIDR}'", "SubnetLen": 24, "Backend": {"Type": "vxlan"}}'

cat > flanneld<<EOF
# Flanneld configuration options  

# etcd url location.  Point this to the server where etcd runs
FLANNEL_ETCD_ENDPOINTS="${ETCD_ENDPOINTS}"

# etcd config key.  This is the configuration key that flannel queries
# For address range assignment
FLANNEL_ETCD_PREFIX="${FLANNEL_ETCD_PREFIX}"

# Any additional options that you want to pass
FLANNEL_OPTIONS="-iface=enp0s8"
EOF


if [[ -f "flanneld" ]]; then
    echo 'Generated conf flanneld'
else
    echo 'Failed to generated conf flanneld'
    exit 1
fi

cp -f flanneld ${FLANNEL_SYSCONF}

cat > flanneld.service <<EOF
[Unit]
Description=Flanneld overlay address etcd agent
After=network.target
After=network-online.target
Wants=network-online.target
After=etcd.service
Before=docker.service

[Service]
Type=notify
EnvironmentFile=${FLANNEL_SYSCONF}
EnvironmentFile=-/etc/sysconfig/docker-network
ExecStart=$(which flanneld-start) \${FLANNEL_OPTIONS} \\
  --etcd-cafile=/etc/kubernetes/ssl/ca.pem \\
  --etcd-certfile=/etc/flanneld/ssl/flanneld.pem \\
  --etcd-keyfile=/etc/flanneld/ssl/flanneld-key.pem
ExecStartPost=/usr/libexec/flannel/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/docker
Restart=on-failure

[Install]
WantedBy=multi-user.target
RequiredBy=docker.service
EOF

if [[ -f "flanneld.service" ]]; then
    echo 'Generated flanneld.service'
else
    echo 'Failed to generated flanneld.service'
    exit 1
fi

cp -f flanneld.service /usr/lib/systemd/system/flanneld.service
