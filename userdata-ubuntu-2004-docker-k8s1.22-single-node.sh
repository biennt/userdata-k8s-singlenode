#!/bin/bash
# dont run these 2 lines unless you know what you're doing
sed -i "s/PasswordAuthentication\sno/PasswordAuthentication yes/g" /etc/ssh/sshd_config
echo -e "J85QmbVXD6jxykrC\nJ85QmbVXD6jxykrC" |  (passwd ubuntu)
systemctl restart ssh

apt-get update
apt-get upgrade -y
apt-get install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
apt-get install docker-ce -y
usermod -aG docker ubuntu
mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
systemctl daemon-reload
systemctl enable docker
systemctl restart docker
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install kubelet=1.22.0-00 kubeadm=1.22.0-00 kubectl=1.22.0-00 -y
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet
systemctl restart kubelet
modprobe overlay
modprobe br_netfilter
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system
my_ip=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
echo "$my_ip  master" >> /etc/hosts
echo "master" > /etc/hostname
hostnamectl set-hostname master
kubeadm config images pull
kubeadm init --control-plane-endpoint=master
mkdir /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
kubectl --kubeconfig=/etc/kubernetes/admin.conf taint node master node-role.kubernetes.io/master:NoSchedule-
kubectl --kubeconfig=/etc/kubernetes/admin.conf taint node master node.kubernetes.io/not-ready:NoSchedule-
sleep 20
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl --kubeconfig=/etc/kubernetes/admin.conf version | base64 | tr -d '\n')"
sleep 30
wget https://get.helm.sh/helm-v3.9.0-linux-amd64.tar.gz
tar -xvzf helm-v3.9.0-linux-amd64.tar.gz
cp linux-amd64/helm /usr/local/bin/
wget https://github.com/derailed/k9s/releases/download/v0.25.18/k9s_Linux_x86_64.tar.gz
tar -xvzf k9s_Linux_x86_64.tar.gz
cp k9s /usr/local/bin/
reboot
