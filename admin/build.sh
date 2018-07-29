#!/bin/bash

source ../env.sh
KUBE_APISERVER="https://${MASTER_URL}:6443"

cat > admin-csr.json <<EOF
{
    "CN": "admin",
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
            "O": "system:masters",
            "OU": "System"
        }
    ]
}
EOF

cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
    -ca-key=/etc/kubernetes/ssl/ca-key.pem \
    -config=/etc/kubernetes/ssl/ca-config.json \
    -profile=kubernetes admin-csr.json | cfssljson -bare admin

cp admin*.pem /etc/kubernetes/ssl

mkdir ~/.kube

# 设置集群参数
kubectl config set-cluster kubernetes \
    --certificate-authority=/etc/kubernetes/ssl/ca.pem \
    --embed-certs=true \
    --server=${KUBE_APISERVER}
# 设置客户端认证参数
kubectl config set-credentials admin \
    --client-certificate=/etc/kubernetes/ssl/admin.pem \
    --embed-certs=true \
    --client-key=/etc/kubernetes/ssl/admin-key.pem \
    --token=${BOOTSTRAP_TOKEN}
# 设置上下文参数
kubectl config set-context kubernetes \
    --cluster=kubernetes \
    --user=admin
# 设置默认上下文
kubectl config use-context kubernetes
