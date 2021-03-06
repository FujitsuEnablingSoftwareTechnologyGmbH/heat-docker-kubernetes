# Getting started with k8s-docker-provisioner

This guide will take you through the steps of deploying Kubernetes to bare metal or Openstack using docker.

## Run on Bare Metal or VM
Kubernetes will be launched on the machine, but no modification is done to the system. The cluster will not survive a reboot.

Login to master and paste the following command:

```
curl -s https://raw.githubusercontent.com/FujitsuEnablingSoftwareTechnologyGmbH/k8s-docker-provisioner/master/master.sh run | sudo sh
```

Login to worker and paste the following command:

```
curl -s https://raw.githubusercontent.com/FujitsuEnablingSoftwareTechnologyGmbH/k8s-docker-provisioner/master/worker.sh run | sudo MASTER_IP=<your-master-ip> sh
```


## Install on Bare Metal or VM
Kubernetes will be permanantly installed on the systems and automatically started after reboot.

Login to master and paste the following command:

```
curl -s https://raw.githubusercontent.com/FujitsuEnablingSoftwareTechnologyGmbH/k8s-docker-provisioner/master/master.sh install | sudo sh
```

Login to worker and paste the following command:
```
curl -s https://raw.githubusercontent.com/FujitsuEnablingSoftwareTechnologyGmbH/k8s-docker-provisioner/master/worker.sh install | sudo MASTER_IP=<your-master-ip> sh
```


## Provision a Cluster on OpenStack

The provisioning includes:
* Virtual machines
* Network
* Installing Kubernetes on the VMs

### Pre-Requisites

Make sure that you have a working OpenStack cluster before starting.

### Install OpenStack CLI tools

- openstack >= 2.4.0
- nova >= 3.2.0
```
 sudo pip install -U python-openstackclient

 sudo pip install -U python-novaclient
```


### Configure Openstack CLI tools

 Please get your OpenStack credential and modify the variables in the following files:

 - **config-default.sh** Sets all parameters needed for heat template.
 - **openrc-default.sh** Sets environment variables for communicating to OpenStack. These are consumed by the cli tools (heat, nova).

### Get kubectl

If you already have the kubectl, you can skip this step.

kubectl is a command-line program for interacting with the Kubernetes API. The following steps should be done from a local workstation to get kubectl.
Download kubectl from the Kubernetes release artifact site with the curl tool.

The linux kubectl binary can be fetched with a command like:
```
$ curl -O https://storage.googleapis.com/kubernetes-release/release/v1.2.0/bin/linux/amd64/kubectl
```

Make kubectl visible in your system.
```
sudo cp kubectl /usr/local/bin
```

### Prepare Openstack image

The provisioning works on any operating system that has a Docker >= 1.10  installed.

Don't forget update IMAGE_ID variable in config-default.sh file.


## Starting a cluster


Execute command:

```
./kube-up.sh
```

When your settings are correct you should see installation progress. Script checks if cluster is available as a final step.

```
... calling verify-prereqs
heat client installed
nova client installed
kubectl client installed
... calling kube-up
kube-up for provider openstack
[INFO] Execute commands to create Kubernetes cluster
[INFO] Key pair already exists
Stack not found: KubernetesStack
[INFO] Create stack KubernetesStack
+--------------------------------------+-----------------+--------------------+----------------------+--------------+
| id                                   | stack_name      | stack_status       | creation_time        | updated_time |
+--------------------------------------+-----------------+--------------------+----------------------+--------------+
| d5ac5664-4dd8-4643-ad89-f71401970892 | KubernetesStack | CREATE_IN_PROGRESS | 2016-04-19T08:23:33Z | None         |
+--------------------------------------+-----------------+--------------------+----------------------+--------------+
... calling validate-cluster
Cluster status CREATE_IN_PROGRESS
Cluster status CREATE_IN_PROGRESS
Cluster status CREATE_IN_PROGRESS
Cluster status CREATE_IN_PROGRESS
Cluster status CREATE_IN_PROGRESS
Cluster status CREATE_IN_PROGRESS
Cluster status CREATE_IN_PROGRESS
Cluster status CREATE_COMPLETE
cluster "heat-docker-kubernetes" set.
context "heat-docker-kubernetes" set.
switched to context "heat-docker-kubernetes".
Wrote config for heat-docker-kubernetes to /home/stack/.kube/config
... calling configure-kubectl
cluster "heat-docker-kubernetes" set.
context "heat-docker-kubernetes" set.
switched to context "heat-docker-kubernetes".
Wrote config for heat-docker-kubernetes to /home/stack/.kube/config
... checking nodes
NAME       STATUS    AGE
10.0.0.3   Ready     1m
10.0.0.4   Ready     20s

```
## Customization

User have possibility to execute custom scripts on master and node before and after provision process.

Scripts must be stored in image directories: 

- /usr/local/pre-scripts  - executed before provision
- /usr/local/post-scripts - executed after provision

User should remember to set correct rights **(rw-r-r)** for scripts.
The /etc/sysconfig/heat-params file contains ROLE variable to distinguish master from node.
