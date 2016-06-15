#!/bin/bash
ETCD_VERSION=${ETCD_VERSION:-"2.2.1"}
docker run \
    --net=host \
    gcr.io/google_containers/etcd:${ETCD_VERSION} \
    etcdctl \
    get /coreos.com/network/config
