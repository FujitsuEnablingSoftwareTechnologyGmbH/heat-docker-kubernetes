#!/bin/bash

# copy cni
cp -R /opt/cni /hostfs/opt
cp /usr/bin/nsenter /hostfs/usr/bin

# copy cni configuration
mkdir -p /hostfs/etc/cni
cp -R /etc/cni/net.d /hostfs/etc/cni
