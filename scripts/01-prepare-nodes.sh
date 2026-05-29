#!/bin/bash
# 01-prepare-nodes.sh
# Preparation de chaque noeud Rocky Linux avant le deploiement Ceph

set -e

echo "==> Installation des paquets necessaires"
dnf install -y cephadm ceph libvirt qemu-kvm virt-install chrony

echo "==> Activation des services"
systemctl enable --now chronyd
systemctl enable --now libvirtd

echo "==> Desactivation du firewall (lab uniquement)"
systemctl stop firewalld
systemctl disable firewalld

echo "==> Verification reseau"
ping -c 2 node2
ping -c 2 node3

echo "==> Verification des disques OSD disponibles"
lsblk

echo "==> Preparation terminee"
