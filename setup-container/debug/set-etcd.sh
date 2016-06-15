#!/bin/bash
ETCD_VERSION=${ETCD_VERSION:-"2.2.1"}
docker run \
    --net=host \
    gcr.io/google_containers/etcd:${ETCD_VERSION} \
    etcdctl \
    set /coreos.com/network/config \
        '{ "Network": "10.1.0.0/16", "Backend": {"Type": "vxlan"}}'
