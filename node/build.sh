#!/bin/bash

source ../env.sh

KUBE_APISERVER="https://${MASTER_URL}:6443"
NODE_IP=192.168.99.104   # 当前部署的节点 IP
KUBELET_POD_INFRA_CONTAINER="gnosoir/gcr.io.pause-amd64:3.0"

MASTER_IP=192.168.99.100
sed -i "/${MASTER_IP}/s/$/ k8s-api.virtual.local k8s-api/" /etc/hosts

## docker ##
cat > docker.service <<EOF
[Unit]
Description=Docker Application Container Engine
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
EnvironmentFile=-/run/flannel/docker
ExecStart=/usr/bin/dockerd --log-level=info \$DOCKER_NETWORK_OPTIONS
ExecReload=/bin/kill -s HUP \$MAINPID
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
# Uncomment TasksMax if your systemd version supports it.
# Only systemd 226 and above support this version.
#TasksMax=infinity
TimeoutStartSec=0
# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes
# kill only the docker process, not all processes in the cgroup
KillMode=process
# restart the docker process if it exits prematurely
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOF

if [[ -f "docker.service" ]]; then
    echo 'Generated docker.service'
else
    echo 'Failed to generated docker.service'
    exit 1
fi
systemctl stop docker
ip link delete docker0
cp -f docker.service /usr/lib/systemd/system/
systemctl daemon-reload
systemctl restart docker && systemctl enable docker && systemctl status docker


## kubelet ##

# create bootstrap.kubeconfig
kubectl config set-cluster kubernetes \
    --certificate-authority=/etc/kubernetes/ssl/ca.pem \
    --embed-certs=true \
    --server=${KUBE_APISERVER} \
    --kubeconfig=bootstrap.kubeconfig
kubectl config set-credentials kubelet-bootstrap \
    --token=${BOOTSTRAP_TOKEN} \
    --kubeconfig=bootstrap.kubeconfig
kubectl config set-context default \
    --cluster=kubernetes \
    --user=kubelet-bootstrap \
    --kubeconfig=bootstrap.kubeconfig
kubectl config use-context default --kubeconfig=bootstrap.kubeconfig
mv bootstrap.kubeconfig /etc/kubernetes/

# kubelet.service
mkdir -p /var/lib/kubelet

cat > kubelet.service <<EOF
[Unit]
Description=Kubernetes Kubelet
After=docker.service
Requires=docker.service

[Service]
WorkingDirectory=/var/lib/kubelet
ExecStart=$(which kubelet) \\
  --cgroup-driver=cgroupfs \\
  --address=${NODE_IP} \\
  --hostname-override=${NODE_IP} \\
  --bootstrap-kubeconfig=/etc/kubernetes/bootstrap.kubeconfig \\
  --kubeconfig=/etc/kubernetes/kubelet.kubeconfig \\
  --cert-dir=/etc/kubernetes/ssl \\
  --cluster-dns=${CLUSTER_DNS_SVC_IP} \\
  --cluster-domain=${CLUSTER_DNS_DOMAIN} \\
  --hairpin-mode promiscuous-bridge \\
  --allow-privileged=true \\
  --pod-infra-container-image=${KUBELET_POD_INFRA_CONTAINER} \\
  --logtostderr=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

if [[ -f "kubelet.service" ]]; then
    echo 'Generated kubelet.service'
else
    echo 'Failed to generated kubelet.service'
    exit 1
fi

# start kubelet service
cp -f kubelet.service /usr/lib/systemd/system/
systemctl daemon-reload
systemctl enable kubelet && systemctl start kubelet
systemctl status kubelet

# approve csr at master node using kubectl
echo """
Approve csr at master node using kubectl

$ kubectl get csr
$ kubectl certificate approve node-csr--k3G2G1EoM4h9w1FuJRjJjfbIPNxa551A8TZfW9dG-g
$ kubectl get nodes

"""
echo -n "Done? "
read kubelet_csr_done

if [ $kubelet_csr_done = 'yes' ]; then
    :
else
    exit 1
fi

## kube-proxy ##

# client cert & key
cat > kube-proxy-csr.json <<EOF
{
    "CN": "system:kube-proxy",
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
    -profile=kubernetes kube-proxy-csr.json | cfssljson -bare kube-proxy
cp -f kube-proxy*.pem /etc/kubernetes/ssl/

# create kube-proxy.kubeconfig
kubectl config set-cluster kubernetes \
    --certificate-authority=/etc/kubernetes/ssl/ca.pem \
    --embed-certs=true \
    --server=${KUBE_APISERVER} \
    --kubeconfig=kube-proxy.kubeconfig
kubectl config set-credentials kube-proxy \
    --client-certificate=/etc/kubernetes/ssl/kube-proxy.pem \
    --client-key=/etc/kubernetes/ssl/kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-proxy.kubeconfig
kubectl config set-context default \
    --cluster=kubernetes \
    --user=kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig
kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

mv kube-proxy.kubeconfig /etc/kubernetes/

# kube-proxy.service
mkdir -p /var/lib/kube-proxy

cat > kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube-Proxy Server
After=network.target

[Service]
WorkingDirectory=/var/lib/kube-proxy
ExecStart=$(which kube-proxy) \\
  --bind-address=${NODE_IP} \\
  --hostname-override=${NODE_IP} \\
  --cluster-cidr=${POD_CIDR} \\
  --kubeconfig=/etc/kubernetes/kube-proxy.kubeconfig \\
  --logtostderr=true \\
  --v=2
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

if [[ -f "kube-proxy.service" ]]; then
    echo 'Generated kube-proxy.service'
else
    echo 'Failed to generated kube-proxy.service'
    exit 1
fi
cp -f kube-proxy.service /usr/lib/systemd/system/
systemctl daemon-reload
systemctl enable kube-proxy && systemctl start kube-proxy
systemctl status kube-proxy
