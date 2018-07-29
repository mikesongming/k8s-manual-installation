# Token used by TLS Bootstrapping
# cmd: head -c 16 /dev/urandom | od -An -t x | tr -d ' '
BOOTSTRAP_TOKEN="b508c46fb8456ea2233dd94b34d5d84b"

# 服务网段(Service CIDR)，部署前路由不可达，部署后集群内部使用IP:Port可达
SERVICE_CIDR="10.254.0.0/16"
# Pod 网段(Cluster CIDR)，部署前路由不可达，部署后路由可达(flanneld 保证)
POD_CIDR="10.236.0.0/16"

# 服务端口范围(NodePort Range)
NODE_PORT_RANGE="30000-32766"

# etcd集群服务地址列表
ETCD_ENDPOINTS="https://192.168.137.104:2379,https://192.168.137.103:2379,https://192.168.137.102:2379"   # one ectd for demo

# flanneld 网络配置前缀
FLANNEL_ETCD_PREFIX="/sf.longfor/network"

# kubernetes 服务IP(预先分配，一般为SERVICE_CIDR中的第一个IP)
CLUSTER_KUBERNETES_SVC_IP="10.254.0.1"

# 集群 DNS 服务IP(从SERVICE_CIDR 中预先分配)
CLUSTER_DNS_SVC_IP="10.254.0.2"

# 集群 DNS 域名
CLUSTER_DNS_DOMAIN="cluster.local"

# MASTER API Server 地址
MASTER_URL="k8s-api.virtual.local"
