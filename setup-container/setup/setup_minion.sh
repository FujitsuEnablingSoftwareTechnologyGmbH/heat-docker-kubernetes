#!/bin/bash
K8S_VERSION=${K8S_VERSION:-"v1.3.0-beta.1"}
ETCD_VERSION=${ETCD_VERSION:-"2.2.1"}
FLANNEL_VERSION=${FLANNEL_VERSION:-"0.5.5"}
FLANNEL_IPMASQ=${FLANNEL_IPMASQ:-"true"}
FLANNEL_IFACE=${FLANNEL_IFACE:-"eth0"}
ARCH=${ARCH:-"amd64"}

if [ -z ${MASTER_IP} ]; then
    echo "Please export MASTER_IP in your env"
    exit 1
fi

if [ -z ${NODE_IP} ]; then
    NODE_IP=$(hostname -I | awk '{print $1}')
fi

# run as root
if [ "$(id -u)" != "0" ]; then
    echo >&2 "Please run as root"
    exit 1
fi

echo "Running flannel ..."
docker run -d \
    --volume=/run/flannel:/run/flannel:rw \
    --restart=on-failure \
    --net=host \
    --privileged \
    -v /dev/net:/dev/net \
    quay.io/coreos/flannel:${FLANNEL_VERSION} \
    /opt/bin/flanneld \
        --ip-masq="${FLANNEL_IPMASQ}" \
        --etcd-endpoints=http://${MASTER_IP}:4001 \
        --iface="${FLANNEL_IFACE}"

echo "Installing CNI..."
docker run -d \
    --volume=/:/hostfs:rw \
    --volume=`pwd`:/setup:ro \
    --net=host \
    --pid=host \
    --privileged \
    taimir93/hyperkube:1 \
    /setup/install_cni.sh

echo "Installing kubernetes ..."
docker run -d \
    --volume=/:/hostfs:rw \
    --volume=`pwd`:/setup:ro \
    --net=host \
    --pid=host \
    --privileged \
    taimir93/hyperkube:1 \
    /setup/install_kubernetes.sh minion

sleep 3

echo "Running kubelet ..."
# systemctl daemon-reload
# systemctl start kubelet
# systemctl enable kubelet
# systemctl status kubelet
/usr/bin/hyperkube kubelet \
    --allow-privileged=true \
    --hostname-override=${NODE_IP} \
    --address="0.0.0.0" \
    --api-servers=http://${MASTER_IP}:8080 \
    --config=/etc/kubernetes/manifests \
    --network-plugin=cni \
    --network-plugin-dir=/etc/cni/net.d \
    --v=2