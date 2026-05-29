#!/bin/bash
# 02-deploy-ceph.sh
# Bootstrap du cluster Ceph avec cephadm et ajout des noeuds

set -e

MON_IP="192.168.247.101"
NODE2="192.168.247.102"
NODE3="192.168.247.103"

echo "==> Bootstrap du cluster Ceph sur node1"
cephadm bootstrap \
  --mon-ip \ \
  --initial-dashboard-user admin \
  --initial-dashboard-password ChangeMoi123!

echo "==> Copie de la cle SSH vers node2 et node3"
ssh-copy-id -f -i /etc/ceph/ceph.pub root@node2
ssh-copy-id -f -i /etc/ceph/ceph.pub root@node3

echo "==> Ajout des noeuds au cluster"
ceph orch host add node2 \
ceph orch host add node3 \

echo "==> Deploiement des MON sur les 3 noeuds"
ceph orch apply mon --placement="3 node1 node2 node3"

echo "==> Deploiement des MGR"
ceph orch apply mgr --placement="2 node1 node2"

echo "==> Deploiement des OSD sur tous les disques disponibles"
ceph orch apply osd --all-available-devices

echo "==> Verification du cluster"
ceph -s
ceph osd tree
