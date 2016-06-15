#!/bin/bash
docker kill $(docker ps -q)
sudo ip link del flannel.1
sudo ip link del cni0
sudo rm -rf /usr/bin/hyperkube
sudo rm -rf /etc/cni
sudo rm -rf /opt/cni
