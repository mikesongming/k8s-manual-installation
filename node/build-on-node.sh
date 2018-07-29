#!/bin/bash

source ../env.sh

KUBE_APISERVER="https://${MASTER_URL}:6443"
NODE_IP=192.168.137.104  # 当前部署的节点 IP
KUBELET_POD_INFRA_CONTAINER="gnosoir/gcr.io.pause-amd64:3.0"


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
cp -f bootstrap.kubeconfig /etc/kubernetes/
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
cp -f kubelet.service /usr/lib/systemd/system/


## kube-proxy ##
cp -f kube-proxy.kubeconfig /etc/kubernetes/
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
