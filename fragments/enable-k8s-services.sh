#!/bin/bash

echo "Enable k8s services"
echo KUBELET_ID=$(docker ps -a -q --filter="name=kubelet") > /etc/sysconfig/kubelet
systemctl enable docker-etcd
systemctl enable docker-flannel
systemctl enable docker-kubelet-master
