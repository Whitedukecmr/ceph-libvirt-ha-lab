#!/bin/bash
# 03-setup-rbd-libvirt.sh
# Creation du pool RBD et integration avec Libvirt/KVM

set -e

echo "==> Creation du pool RBD"
ceph osd pool create libvirt-pool 64 64
ceph osd pool application enable libvirt-pool rbd
rbd pool init libvirt-pool

echo "==> Creation de l utilisateur Ceph pour Libvirt"
ceph auth get-or-create client.libvirt \
  mon 'profile rbd' \
  osd 'profile rbd pool=libvirt-pool' \
  mgr 'profile rbd pool=libvirt-pool' \
  -o /etc/ceph/ceph.client.libvirt.keyring

echo "==> Creation du secret Libvirt"
CEPH_KEY=\
UUID=\
virsh secret-set-value --secret \ --base64 \
echo "UUID du secret : \"

echo "==> Declaration du pool ceph-rbd dans Libvirt"
sed -i "s/REMPLACER_PAR_UUID/\/" /root/configs/ceph-pool.xml
virsh pool-define /root/configs/ceph-pool.xml
virsh pool-autostart ceph-rbd
virsh pool-start ceph-rbd

echo "==> Verification"
virsh pool-list --all
rbd ls -p libvirt-pool

echo "==> Integration RBD/Libvirt terminee"
