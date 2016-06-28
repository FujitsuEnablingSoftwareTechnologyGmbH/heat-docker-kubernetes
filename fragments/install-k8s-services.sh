#!/bin/bash

echo "Create k8s services"

tee /usr/lib/systemd/system/docker-etcd.service <<-'EOF'
[Unit]
Description=Start etcd
Wants=docker-bootstrap.service
After=docker.service docker-bootstrap.service

[Service]
EnvironmentFile=/etc/sysconfig/heat-params
ExecStart=/bin/docker -H unix:///var/run/docker-bootstrap.sock run \
        --restart=on-failure \
        --net=host \
        -d \
        gcr.io/google_containers/etcd-amd64:2.2.1 \
        /usr/local/bin/etcd \
            --listen-client-urls=http://127.0.0.1:4001,http://${MASTER_IP}:4001 \
            --advertise-client-urls=http://${MASTER_IP}:4001 \
            --data-dir=/var/etcd/data
[Install]
WantedBy=multi-user.target
EOF

echo "Service docker-etcd added"

tee /usr/lib/systemd/system/docker-flannel.service <<-'EOF'
[Unit]
Description=Start flannel
Wants=docker-bootstrap.service
After=docker.service docker-bootstrap.service docker-etcd.service

[Service]
ExecStart=/bin/docker -H unix:///var/run/docker-bootstrap.sock run \
        --restart=on-failure \
        -d \
        --net=host \
        --privileged \
        -v /dev/net:/dev/net \
        quay.io/coreos/flannel:0.5.5 \
        /opt/bin/flanneld \
            --ip-masq=true \
            --iface=eth0
[Install]
WantedBy=multi-user.target
EOF

echo "Service docker-flannel added"

tee /usr/lib/systemd/system/docker-kubelet-master.service <<-'EOF'
[Unit]
Description=Start kubelet
Wants=docker-flannel.service
After=docker.service docker-bootstrap.service docker-etcd.service docker-flannel.service

[Service]
EnvironmentFile=/etc/sysconfig/kubelet
ExecStart=/bin/docker start $KUBELET_ID

[Install]
WantedBy=multi-user.target
EOF

echo "Service docker-kubelet-master added"
