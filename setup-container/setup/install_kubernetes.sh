#!/bin/bash
node=$1
if [ "$node" != "master" ] && [ "$node" != "minion" ]; then
  "You must specify 'master' or 'minion' as argument"
  exit 1
fi

# copy hyperkube binary
cp /hyperkube /hostfs/usr/bin/

# copy kubelet service configuration
cp /setup/kubelet.service /etc/systemd/system/

if [ "$node" == "master" ]; then
  # clean up old configuration
  rm -rf /hostfs/var/lib/kubelet
  rm -rf /hostfs/etc/kubernetes/manifests
  rm -rf /hostfs/etc/kubernetes/addons

  mkdir -p /hostfs/etc/kubernetes/manifests
  mkdir -p /hostfs/etc/kubernetes/addons

  # copy master components and addons
  cp /etc/kubernetes/manifests-multi/master-multi.json /hostfs/etc/kubernetes/manifests/
  cp /etc/kubernetes/manifests-multi/addon-manager.json /hostfs/etc/kubernetes/manifests/
  cp -R /etc/kubernetes/addons /hostfs/etc/kubernetes
fi
