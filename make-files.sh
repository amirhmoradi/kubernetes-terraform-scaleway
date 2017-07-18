#!/bin/bash -v
. ./terratemp.ips.txt
. ./terratemp.master_ips.txt

cat > terratemp.scw-install.sh <<-FINSW
#!/usr/bin/env bash

SUID=\$(scw-metadata --cached ID)
PUBLIC_IP=\$(scw-metadata --cached PUBLIC_IP_ADDRESS)
PRIVATE_IP=\$(scw-metadata --cached PRIVATE_IP)
HOSTNAME=\$(scw-metadata --cached HOSTNAME)

# modify hostname to allow communication between Scaleway instances.
hostname \$HOSTNAME
echo \$HOSTNAME > /etc/hostname
echo "127.0.0.1 \$HOSTNAME" >> /etc/hosts


for arg in "\$@"
do
  case \$arg in
    'rancher-server')
      export DEBIAN_FRONTEND=noninteractive
      sudo docker run -d --restart=unless-stopped -p 8080:8080 rancher/server
      break
      ;;
    'k8s-master')
      # Install Kubernetes APT
      export DEBIAN_FRONTEND=noninteractive
      curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
      echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list

      sudo killall apt-get
      sudo killall apt
      sudo killall update-manager
      sudo systemctl stop apt-daily.timer
      sleep 30
      sudo apt-get update -yq && apt-get install -y -q kubelet kubeadm kubectl kubernetes-cni && apt-get clean

      kubeadm init --token=\$CLUSTER_TOKEN --apiserver-advertise-address=\$PUBLIC_IP --apiserver-bind-port=$MASTER_00_PORT --service-dns-domain=\$SUID.pub.cloud.scaleway.com

      mkdir -p \$HOME/.kube
      sudo cp /etc/kubernetes/admin.conf \$HOME/.kube/config
      sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config

      export KUBECONFIG=\$HOME/.kube/config

      KUBECONFIG=\$HOME/.kube/config kubectl apply -f https://git.io/weave-kube-1.6
      sleep 60
      # see http://kubernetes.io/docs/user-guide/ui/
      KUBECONFIG=\$HOME/.kube/config kubectl create -f https://git.io/kube-dashboard
      break
      ;;
    'k8s-agent')
      # Install Kubernetes APT
      export DEBIAN_FRONTEND=noninteractive
      curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
      echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list

      sudo killall apt-get
      sudo killall apt
      sudo killall update-manager
      sudo systemctl stop apt-daily.timer
      sleep 30
      sudo apt-get update -yq && apt-get install -y -q kubelet kubeadm kubectl kubernetes-cni && apt-get clean && \
      kubeadm join --token \$CLUSTER_TOKEN $MASTER_00:$MASTER_00_PORT --skip-preflight-checks
      break
      ;;
 esac
done
FINSW

cat > terratemp.prep-sys-ubuntu.sh <<-FINPREP
#!/bin/bash -v

if [ -f /var/prep-done-\$CLUSTER_NAME.lock ]; then
  exit 0;
fi
# Update system, install tools and whisles
sudo apt-get update -q -y
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -q -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq git nano unzip ipset apt-transport-https ca-certificates curl software-properties-common glusterfs-client

cat >> /etc/apt/apt.conf.d/10periodic <<-EOFAU
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOFAU

sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq -o Dpkg::Options::="--force-confnew --force-confdef" unattended-upgrades

# Enable overlay and overlay2 storage-driver
sudo echo 'overlay' > /etc/modules-load.d/overlay.conf
sudo echo 'overlay2' > /etc/modules-load.d/overlay2.conf

## Install Docker
# Cleanup previous docker installs
sudo apt-get -y remove docker docker-common container-selinux docker-selinux docker-engine

sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get -y install docker-ce

# Tune docker
sudo mkdir -p /etc/systemd/system/docker.service.d && sudo tee /etc/systemd/system/docker.service.d/override.conf <<-FINTD
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --storage-driver=overlay2 --mtu=1500
FINTD
echo "DOCKER_OPTS='-H unix:///var/run/docker.sock --storage-driver overlay2 --label provider=scaleway --mtu=1500 --insecure-registry=10.0.0.0/8'" > /etc/default/docker

# Enable and start services
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl start docker
sleep 5
##Not tested:
#sudo systemctl enable kube-proxy
#sudo systemctl start kube-proxy
#sudo systemctl enable kubelet
#sudo systemctl start kubelet
touch /var/prep-done-$CLUSTER_NAME.lock
FINPREP

#rm -rf ./terratemp.ips.txt
