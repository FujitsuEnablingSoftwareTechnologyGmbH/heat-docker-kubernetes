#!/bin/bash
K8S_VERSION=${K8S_VERSION:-"v1.3.0-beta.1"}
ETCD_VERSION=${ETCD_VERSION:-"2.2.1"}
FLANNEL_VERSION=${FLANNEL_VERSION:-"0.5.5"}
FLANNEL_IPMASQ=${FLANNEL_IPMASQ:-"true"}
FLANNEL_IFACE=${FLANNEL_IFACE:-"eth0"}
FLANNEL_CIDR=${FLANNEL_CIDR:-"10.1.0.0/16"}
ARCH=${ARCH:-"amd64"}
if [ -z ${MASTER_IP} ]; then
    MASTER_IP=$(hostname -I | awk '{print $1}')
fi

# run as root
if [ "$(id -u)" != "0" ]; then
    echo >&2 "Please run as root"
    exit 1
fi

echo "Running etcd ..."
docker run \
    --restart=on-failure \
    --net=host \
    -d \
    gcr.io/google_containers/etcd-${ARCH}:${ETCD_VERSION} \
    /usr/local/bin/etcd \
        --listen-client-urls=http://127.0.0.1:4001,http://${MASTER_IP}:4001 \
        --advertise-client-urls=http://${MASTER_IP}:4001 \
        --data-dir=/var/etcd/data

sleep 1

# setup flannel overlay
echo "Placing flannel configuration in etcd ..."
docker run \
    --net=host \
    gcr.io/google_containers/etcd:${ETCD_VERSION} \
    etcdctl \
    set /coreos.com/network/config \
        '{ "Network": "10.1.0.0/16", "Backend": {"Type": "vxlan"}}'

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
    /setup/install_kubernetes.sh master

sleep 3

echo "Running kubelet ..."
systemctl daemon-reload
systemctl start kubelet
systemctl enable kubelet
systemctl status kubelet
