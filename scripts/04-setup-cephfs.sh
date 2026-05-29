#!/bin/bash
# 04-setup-cephfs.sh
# Creation du CephFS et montage automatique via systemd

set -e

echo "==> Creation du volume CephFS"
ceph fs volume create cephfs

echo "==> Verification des MDS"
ceph orch ps --daemon-type mds
ceph fs status

echo "==> Creation du point de montage"
mkdir -p /mnt/cephfs

echo "==> Stockage de la cle d acces"
ceph auth get-key client.admin > /etc/ceph/cephfs.secret
chmod 600 /etc/ceph/cephfs.secret

echo "==> Installation du unit file systemd"
cp /root/configs/mnt-cephfs.mount /etc/systemd/system/mnt-cephfs.mount

echo "==> Activation du montage automatique"
systemctl daemon-reload
systemctl enable mnt-cephfs.mount
systemctl start mnt-cephfs.mount

echo "==> Verification"
systemctl status mnt-cephfs.mount
df -h /mnt/cephfs

echo "==> Test ecriture/lecture"
echo "CephFS OK depuis \DESKTOP-BBDO5TE" > /mnt/cephfs/test-cephfs.txt
cat /mnt/cephfs/test-cephfs.txt

echo "==> CephFS configure et monte avec succes"
