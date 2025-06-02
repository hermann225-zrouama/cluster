#!/bin/bash
set -e

# Alternative plus simple au rke2-killall.sh pour éviter les problèmes de fork

echo "=== Nettoyage RKE2 alternatif ==="

# Variables
RKE2_DATA_DIR=${RKE2_DATA_DIR:-/var/lib/rancher/rke2}

# Arrêter les services
echo "Arrêt des services RKE2..."
systemctl stop rke2-server.service 2>/dev/null || true
systemctl stop rke2-agent.service 2>/dev/null || true

# Tuer les processus RKE2 de manière plus simple
echo "Arrêt des processus RKE2..."
pkill -f "rke2" 2>/dev/null || true
pkill -f "containerd-shim" 2>/dev/null || true
pkill -f "kubelet" 2>/dev/null || true

# Attendre un peu
sleep 5

# Force kill si nécessaire
pkill -9 -f "rke2" 2>/dev/null || true
pkill -9 -f "containerd-shim" 2>/dev/null || true
pkill -9 -f "kubelet" 2>/dev/null || true

# Démontage des points de montage
echo "Démontage des volumes..."
for mount in $(mount | grep -E "(k3s|kubelet|cni)" | awk '{print $3}' | sort -r); do
    echo "Démontage de $mount"
    umount "$mount" 2>/dev/null || true
done

# Suppression des interfaces réseau
echo "Suppression des interfaces réseau..."
for iface in cni0 flannel.1 flannel.4096 flannel-v6.1 flannel-v6.4096 \
             flannel-wg flannel-wg-v6 vxlan.calico vxlan-v6.calico \
             cilium_vxlan cilium_net cilium_wg0 kube-ipvs0 nodelocaldns; do
    if ip link show "$iface" >/dev/null 2>&1; then
        echo "Suppression interface $iface"
        ip link delete "$iface" 2>/dev/null || true
    fi
done

# Suppression des interfaces avec master cni0
ip link show 2>/dev/null | grep 'master cni0' | while read ignore iface ignore; do
    iface=${iface%%@*}
    if [ -n "$iface" ]; then
        echo "Suppression interface $iface"
        ip link delete "$iface" 2>/dev/null || true
    fi
done

# Nettoyage des règles iptables (version simplifiée)
echo "Nettoyage des règles iptables..."
iptables-save | grep -v -E "(KUBE-|CNI-|cali-|cali:|CILIUM_|flannel)" | iptables-restore 2>/dev/null || true
ip6tables-save | grep -v -E "(KUBE-|CNI-|cali-|cali:|CILIUM_|flannel)" | ip6tables-restore 2>/dev/null || true

# Suppression des répertoires
echo "Suppression des répertoires..."
rm -rf /var/lib/cni/ /var/log/pods/ /var/log/containers 2>/dev/null || true

# Suppression des manifests
POD_MANIFESTS_DIR=${RKE2_DATA_DIR}/agent/pod-manifests
if [ -d "$POD_MANIFESTS_DIR" ]; then
    rm -f "${POD_MANIFESTS_DIR}/etcd.yaml" \
          "${POD_MANIFESTS_DIR}/kube-apiserver.yaml" \
          "${POD_MANIFESTS_DIR}/kube-controller-manager.yaml" \
          "${POD_MANIFESTS_DIR}/cloud-controller-manager.yaml" \
          "${POD_MANIFESTS_DIR}/kube-scheduler.yaml" \
          "${POD_MANIFESTS_DIR}/kube-proxy.yaml" 2>/dev/null || true
fi

echo "=== Nettoyage terminé ==="
echo "Vous pouvez maintenant exécuter le script de désinstallation principal."
