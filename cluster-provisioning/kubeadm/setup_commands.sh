# Configure SystemdCgroup on all nodes (controlplane and worker nodes)
containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' | sudo tee /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

# Verify the SystemdCgroup config change
cat /etc/containerd/config.toml | grep -i "systemdCgroup" -B 50

# Enable IP forwarding on all nodes (controlplane and worker nodes)

# Configure the required kernel modules to load on boot
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Load the modules immediately
sudo modprobe overlay
sudo modprobe br_netfilter

# Configure the required sysctl routing parameters permanently
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply the changes from the file to active memory
sudo sysctl --system

# Initialize controlplane
sudo kubeadm init --apiserver-advertise-address 192.168.56.11 --pod-network-cidr "10.244.0.0/16" --upload-certs

# To start using your cluster, you need to run the following as a regular user:
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# IMPORTANT: Save the kubeadm join command shown in the output of the previous command. You will need it to join the worker nodes to the cluster.

# Verify kubectl command is working (controlplane status is expected to be NotReady)
kubectl get nodes

# Download network plugin
wget https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Verify the Network CIDR under net-conf.json section of kube-flannel.yml and make sure that it matches with the one used during kubeadm init

# Apply the network plugin
kubectl apply -f kube-flannel.yml

# Verify the flannel pod
kubectl get pod -n kube-flannel

# Verify controplane status now changes to Ready
kubectl get nodes

# IMPORTANT: Run the kubeadm join command on worker nodes (copy from the output of the kubeadm init command)

# Verify that all the nodes now show Ready status
kubectl get nodes

