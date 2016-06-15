#
# Creates hyperkube with CNI binaries and flannel configuration
#

FROM gcr.io/google_containers/hyperkube-amd64:v1.3.0-beta.1
RUN apt-get update && apt-get upgrade
RUN apt-get install xz-utils

RUN mkdir -p /opt/cni/bin
RUN mkdir -p /etc/cni/net.d
RUN mkdir -p /var/run/flannel

WORKDIR /tmp

RUN curl -L https://github.com/containernetworking/cni/releases/download/v0.3.0/cni-v0.3.0.txz -O
RUN tar xvf cni-v0.3.0.txz -C /opt/cni/bin
RUN rm cni-v0.3.0.txz

COPY 10-k8s-overlay.conf /etc/cni/net.d
COPY 99-loopback.conf /etc/cni/net.d
