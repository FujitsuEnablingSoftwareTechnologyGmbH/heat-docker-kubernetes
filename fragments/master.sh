#!/bin/bash

# Copyright 2015 The Kubernetes Authors All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# A script to setup the k8s master in docker containers.
# Authors @wizard_cxy @resouer

set -e

# Make sure docker daemon is running
if ( ! ps -ef | grep "/usr/bin/docker" | grep -v 'grep' &> /dev/null ); then
    echo "Docker is not running on this machine!"
    exit 1
fi

# Make sure k8s version env is properly set
ARCH=${ARCH:-"amd64"}

# Make sure k8s images are properly set
ETCD_IMAGE=${ETCD_IMAGE:-gcr.io/google_containers/etcd-amd64:2.2.1}
HYPERKUBE_IMAGE=${HYPERKUBE_IMAGE:-gcr.io/google_containers/hyperkube-amd64:v1.2.0}
ADDONS_IMAGE=${ADDONS_IMAGE:-fest/addons_services:latest}
PAUSE_IMAGE=${PAUSE_IMAGE:-gcr.io/google_containers/pause:2.0}

# Run as root
if [ "$(id -u)" != "0" ]; then
    echo >&2 "Please run as root"
    exit 1
fi

# Make sure master ip is properly set
if [ -z ${MASTER_IP} ]; then
    MASTER_IP=$(hostname -I | awk '{print $1}')
fi

echo "MASTER_IP is set to: ${MASTER_IP}"
echo "ARCH is set to: ${ARCH}"

# Check if a command is valid
command_exists() {
    command -v "$@" > /dev/null 2>&1
}

lsb_dist=""

# Detect the OS distro, we support ubuntu, debian, mint, centos, fedora dist
detect_lsb() {
    # TODO: remove this when ARM support is fully merged
    case "$(uname -m)" in
        *64)
            ;;
         *)
            echo "Error: We currently only support 64-bit platforms."
            exit 1
            ;;
    esac

    if command_exists lsb_release; then
        lsb_dist="$(lsb_release -si)"
    fi
    if [ -z ${lsb_dist} ] && [ -r /etc/lsb-release ]; then
        lsb_dist="$(. /etc/lsb-release && echo "$DISTRIB_ID")"
    fi
    if [ -z ${lsb_dist} ] && [ -r /etc/debian_version ]; then
        lsb_dist='debian'
    fi
    if [ -z ${lsb_dist} ] && [ -r /etc/fedora-release ]; then
        lsb_dist='fedora'
    fi
    if [ -z ${lsb_dist} ] && [ -r /etc/os-release ]; then
        lsb_dist="$(. /etc/os-release && echo "$ID")"
    fi

    lsb_dist="$(echo ${lsb_dist} | tr '[:upper:]' '[:lower:]')"

    case "${lsb_dist}" in
        amzn|centos|debian|ubuntu)
            ;;
        *)
            echo "Error: We currently only support ubuntu|debian|amzn|centos."
            exit 1
            ;;
    esac
}


# Start k8s components in containers
DOCKER_CONF=""

start_k8s(){
	
	# Configure docker
    case "${lsb_dist}" in
        amzn)
            DOCKER_CONF="/etc/sysconfig/docker"
            ;;
        centos)
            DOCKER_CONF="/usr/lib/systemd/system/docker.service"
            ;;
        ubuntu|debian)
            DOCKER_CONF="/etc/default/docker"
            ;;
        *)
            echo "Unsupported operations system ${lsb_dist}"
            exit 1
            ;;
    esac
	
	  
    if command_exists systemctl; then
        sed -i.bak 's/^\(MountFlags=\).*/\1shared/' $DOCKER_CONF
        systemctl daemon-reload
        systemctl restart docker
    fi
	
	sleep 5
	
    # Start etcd
    docker run \
        --restart=on-failure \
        --net=host \
        -d \
        ${ETCD_IMAGE} \
        /usr/local/bin/etcd \
            --listen-client-urls=http://127.0.0.1:4001,http://${MASTER_IP}:4001 \
            --advertise-client-urls=http://${MASTER_IP}:4001 \
            --data-dir=/var/etcd/data

    sleep 5


    # Start kubelet and then start master components as pods
    mkdir -p /var/lib/kubelet
    mount --bind /var/lib/kubelet /var/lib/kubelet
    mount --make-shared /var/lib/kubelet

    docker run \
        --name=kubelet \
        --volume=/:/rootfs:ro \
        --volume=/sys:/sys:ro \
        --volume=/var/lib/docker/:/var/lib/docker:rw \
        --volume=/var/run:/var/run:rw \
        --volume=/var/lib/kubelet:/var/lib/kubelet:shared \
        --net=host \
        --pid=host \
        --privileged=true \
        -d \
        ${HYPERKUBE_IMAGE} \
        /hyperkube kubelet \
            --hostname-override=${MASTER_IP} \
            --address="0.0.0.0" \
            --api-servers=http://localhost:8080 \
            --config=/etc/kubernetes/manifests-multi \
            --cluster-dns=10.0.0.10 \
            --cluster-domain=cluster.local \
            --allow-privileged=true --v=2 \
            --pod-infra-container-image=${PAUSE_IMAGE} \
            --experimental-flannel-overlay=true
}

run_addons_container(){
  docker run \
      --net=host \
      -d \
      ${ADDONS_IMAGE}
}

set +e
deploy_add_ons(){
  # poll the server until it starts up then run addons
  wait_on_api_server
  run_addons_container
}

wait_on_api_server(){
  # init vars
  which curl > /dev/null || {
    echo "curl must be installed"
    exit 1
  }

  local URL='http://localhost:8080/healthz'
  local RESPONSE=$(curl --write-out %{http_code} --silent --output /dev/null $URL )
  local OK_STATUS=200
  local TIMEOUT=300 # 5 minutes
  local INTERVAL=5 # every 5 seconds

  local NEXT_WAIT_TIME=0
  until [ ${RESPONSE:-0} -eq $OK_STATUS ] || [ $NEXT_WAIT_TIME -eq $TIMEOUT ]; do
    sleep ${INTERVAL}
    RESPONSE=$(curl --write-out %{http_code} --silent --output /dev/null $URL )
    let NEXT_WAIT_TIME=NEXT_WAIT_TIME+INTERVAL
  done

  if [ ${RESPONSE:-0} -eq $OK_STATUS ]; then
        echo "Success: Response 200 received from API service ..."
  elif [ $NEXT_WAIT_TIME -eq $TIMEOUT ]; then
        echo "Error: Timeout has occurred while trying to contact the API service ..."
  else
        echo "Error: API service cannot be reched ..."
  fi
}

set_docker_registry(){

	# Add docker registry as prefix for k8s images.
	if [[ -n ${DOCKER_REGISTRY_PREFIX} ]]; then
	  ETCD_IMAGE=${DOCKER_REGISTRY_PREFIX}/${ETCD_IMAGE}
	  HYPERKUBE_IMAGE=${DOCKER_REGISTRY_PREFIX}/${HYPERKUBE_IMAGE}
	  ADDONS_IMAGE=${DOCKER_REGISTRY_PREFIX}/${ADDONS_IMAGE}
	  PAUSE_IMAGE=${DOCKER_REGISTRY_PREFIX}/${PAUSE_IMAGE}
	fi

    case "${lsb_dist}" in
        centos)
			DOCKER_CONF="/usr/lib/systemd/system/docker.service"
			DOCKER_BOOTSTRAP_CONF="/usr/lib/systemd/system/docker-bootstrap.service"
			if [[ -n ${DOCKER_REGISTRY_URL} ]]; then
			  sed -i "/^ExecStart=/ s~$~ --insecure-registry=${DOCKER_REGISTRY_URL}~" ${DOCKER_CONF}
			  sed -i "/graph=/ s~$~ --insecure-registry=${DOCKER_REGISTRY_URL}~" ${DOCKER_BOOTSTRAP_CONF}
			  systemctl daemon-reload
			  systemctl restart docker
			  systemctl restart docker-bootstrap
			fi
            ;;
        *)
            echo "Unsupported operations system ${lsb_dist} for docker registry"
            ;;
    esac
}

set -e

echo "Detecting your OS distro ..."
detect_lsb

echo "Set docker registry"
set_docker_registry

echo "Starting k8s ..."
start_k8s

echo "Start polling for API service ..."
set +e
deploy_add_ons &
set -e

echo "Master done!"
