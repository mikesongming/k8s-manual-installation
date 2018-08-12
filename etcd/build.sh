#!/bin/bash

export NODE_NAME=test05 # 当前部署的机器名称(随便定义，只要能区分不同机器即可)
export NODE_IP=192.168.137.104 # 当前部署的机器IP
export NODE_IPS="192.168.137.104 192.168.137.103 192.168.137.102" # etcd 集群所有机器 IP
# etcd 集群间通信的IP和端口
export ETCD_NODES="test05=https://192.168.137.104:2380,test04=https://192.168.137.103:2380,test03=https://192.168.137.102:2380"
# 导入用到的其它全局变量：ETCD_ENDPOINTS、FLANNEL_ETCD_PREFIX、POD_CIDR

# Pod 网段(Cluster CIDR)，部署前路由不可达，部署后路由可达(flanneld 保证)
POD_CIDR="10.236.0.0/16"

# etcd集群服务地址列表
ETCD_ENDPOINTS="https://192.168.137.104:2379,https://192.168.137.103:2379,https://192.168.137.102:2379"   # one ectd for demo

# flanneld 网络配置前缀
FLANNEL_ETCD_PREFIX="/sf.longfor/network"

cat > etcd-csr.json <<EOF
{
    "CN": "etcd",
        "hosts": [
            "127.0.0.1",
            "${NODE_IP}"
        ],
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

if [[ -f "etcd-csr.json" ]]; then
    echo 'Generated etcd-csr.json'
else
    echo 'Failed to generated etcd-csr.json'
    exit 1
fi

cfssl gencert -ca=/etc/kubernetes/ssl/ca.pem \
    -ca-key=/etc/kubernetes/ssl/ca-key.pem \
    -config=/etc/kubernetes/ssl/ca-config.json \
    -profile=kubernetes etcd-csr.json | cfssljson -bare etcd

mkdir -p /etc/etcd/ssl
cp etcd*.pem /etc/etcd/ssl/
chown etcd:etcd /etc/etcd/ssl/etcd*.pem


cat > etcd.conf <<EOF
#[Member]
#ETCD_CORS=""
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
#ETCD_WAL_DIR=""
ETCD_LISTEN_PEER_URLS="https://${NODE_IP}:2380"
ETCD_LISTEN_CLIENT_URLS="http://localhost:2379,https://${NODE_IP}:2379"
#ETCD_MAX_SNAPSHOTS="5"
#ETCD_MAX_WALS="5"
ETCD_NAME="${NODE_NAME}"
#ETCD_SNAPSHOT_COUNT="100000"
#ETCD_HEARTBEAT_INTERVAL="100"
#ETCD_ELECTION_TIMEOUT="1000"
#ETCD_QUOTA_BACKEND_BYTES="0"
#ETCD_MAX_REQUEST_BYTES="1572864"
#ETCD_GRPC_KEEPALIVE_MIN_TIME="5s"
#ETCD_GRPC_KEEPALIVE_INTERVAL="2h0m0s"
#ETCD_GRPC_KEEPALIVE_TIMEOUT="20s"
#
#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://${NODE_IP}:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://${NODE_IP}:2379"
#ETCD_DISCOVERY=""
#ETCD_DISCOVERY_FALLBACK="proxy"
#ETCD_DISCOVERY_PROXY=""
#ETCD_DISCOVERY_SRV=""
ETCD_INITIAL_CLUSTER="${ETCD_NODES}"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
#ETCD_STRICT_RECONFIG_CHECK="true"
#ETCD_ENABLE_V2="true"
#
#[Proxy]
#ETCD_PROXY="off"
#ETCD_PROXY_FAILURE_WAIT="5000"
#ETCD_PROXY_REFRESH_INTERVAL="30000"
#ETCD_PROXY_DIAL_TIMEOUT="1000"
#ETCD_PROXY_WRITE_TIMEOUT="5000"
#ETCD_PROXY_READ_TIMEOUT="0"
#
#[Security]
ETCD_CERT_FILE="/etc/etcd/ssl/etcd.pem"
ETCD_KEY_FILE="/etc/etcd/ssl/etcd-key.pem"
#ETCD_CLIENT_CERT_AUTH="false"
ETCD_TRUSTED_CA_FILE="/etc/kubernetes/ssl/ca.pem"
#ETCD_AUTO_TLS="false"
ETCD_PEER_CERT_FILE="/etc/etcd/ssl/etcd.pem"
ETCD_PEER_KEY_FILE="/etc/etcd/ssl/etcd-key.pem"
#ETCD_PEER_CLIENT_CERT_AUTH="false"
ETCD_PEER_TRUSTED_CA_FILE="/etc/kubernetes/ssl/ca.pem"
#ETCD_PEER_AUTO_TLS="false"
#
#[Logging]
#ETCD_DEBUG="false"
#ETCD_LOG_PACKAGE_LEVELS=""
#ETCD_LOG_OUTPUT="default"
#
#[Unsafe]
#ETCD_FORCE_NEW_CLUSTER="false"
#
#[Version]
#ETCD_VERSION="false"
#ETCD_AUTO_COMPACTION_RETENTION="0"
#
#[Profiling]
#ETCD_ENABLE_PPROF="false"
#ETCD_METRICS="basic"
#
#[Auth]
#ETCD_AUTH_TOKEN="simple"
EOF

if [[ -f "etcd.conf" ]]; then
    echo 'Generated etcd.conf'
else
    echo 'Failed to generated etcd.conf'
    exit 1
fi

cp -f etcd.conf /etc/etcd/etcd.conf


cat > etcd.service <<EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
WorkingDirectory=/var/lib/etcd/
EnvironmentFile=-/etc/etcd/etcd.conf
User=etcd
# set GOMAXPROCS to number of processors
ExecStart=/bin/bash -c "GOMAXPROCS=$(nproc) $(which etcd) --name=\"\${ETCD_NAME}\" --data-dir=\"\${ETCD_DATA_DIR}\" --listen-client-urls=\"\${ETCD_LISTEN_CLIENT_URLS}\""
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

if [[ -f "etcd.service" ]]; then
    echo 'Generated etcd.service'
else
    echo 'Failed to generated etcd.service'
    exit 1
fi

cp -f etcd.service /usr/lib/systemd/system/etcd.service
