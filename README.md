# 🔷 Ceph Libvirt HA Lab

> **Infrastructure hyperconvergée** — Cluster Ceph 3 nœuds avec stockage distribué RBD, CephFS et intégration Libvirt/KVM en environnement VMware Workstation. Live migration de VMs validée entre nœuds KVM.

![Rocky Linux](https://img.shields.io/badge/OS-Rocky_Linux_10.1-10B981?style=flat-square&logo=linux&logoColor=white)
![Ceph](https://img.shields.io/badge/Ceph-19.2.3_Squid-EF4444?style=flat-square)
![KVM](https://img.shields.io/badge/Hypervisor-KVM_%2F_libvirt-3B82F6?style=flat-square)
![cephadm](https://img.shields.io/badge/Orchestrator-cephadm-8B5CF6?style=flat-square)
![VMware](https://img.shields.io/badge/Lab-VMware_Workstation-607D8B?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)

---

## 📐 Architecture globale

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        VMware Workstation (Hôte physique)                   │
│                         Réseau : 192.168.247.0/24                           │
│                                                                             │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │
│  │     node1        │  │     node2        │  │     node3        │          │
│  │ 192.168.247.101  │  │ 192.168.247.102  │  │ 192.168.247.103  │          │
│  │  Rocky Linux 10  │  │  Rocky Linux 10  │  │  Rocky Linux 10  │          │
│  │                  │  │                  │  │                  │          │
│  │  ● MON  (lead)   │  │  ● MON           │  │  ● MON           │          │
│  │  ● MGR  (lead)   │  │  ● MGR (standby) │  │  ● MDS           │          │
│  │  ● OSD.0         │  │  ● OSD.3         │  │  ● OSD.6         │          │
│  │  ● OSD.1         │  │  ● OSD.4         │  │  ● OSD.7         │          │
│  │  ● OSD.2         │  │  ● OSD.5         │  │  ● OSD.8         │          │
│  │  ● Libvirt/KVM   │  │  ● Libvirt/KVM   │  │  ● Libvirt/KVM   │          │
│  │                  │  │                  │  │                  │          │
│  │  /dev/sdb ─┐     │  │  /dev/sdb ─┐    │  │  /dev/sdb ─┐    │          │
│  │  /dev/sdc ─┤     │  │  /dev/sdc ─┤    │  │  /dev/sdc ─┤    │          │
│  │  /dev/sdd ─┘     │  │  /dev/sdd ─┘    │  │  /dev/sdd ─┘    │          │
│  │  (3 × 100 Go)    │  │  (3 × 100 Go)   │  │  (3 × 100 Go)   │          │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘          │
│           │                     │                     │                    │
│           └─────────────────────┼─────────────────────┘                   │
│                                 │                                          │
│                    ┌────────────▼────────────┐                             │
│                    │      CEPH CLUSTER        │                             │
│                    │   (Ceph 19.2.3 Squid)    │                             │
│                    │                          │                             │
│                    │  ┌────────────────────┐  │                             │
│                    │  │   Pool RBD         │  │                             │
│                    │  │   libvirt-pool     │  │                             │
│                    │  │   → disques VMs    │  │                             │
│                    │  │   → live migration │  │                             │
│                    │  └────────────────────┘  │                             │
│                    │                          │                             │
│                    │  ┌────────────────────┐  │                             │
│                    │  │   CephFS           │  │                             │
│                    │  │   monté sur        │  │                             │
│                    │  │   /mnt/cephfs      │  │                             │
│                    │  └────────────────────┘  │                             │
│                    └──────────────────────────┘                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🌊 Flux de données

```
                    ┌──────────────────────────────┐
                    │   Client / Hyperviseur KVM    │
                    └──────────────┬───────────────┘
                                   │
               ┌───────────────────▼───────────────────┐
               │                                       │
      ┌────────▼────────┐                   ┌──────────▼───────┐
      │   Accès RBD     │                   │   Accès CephFS   │
      │  (bloc VM)      │                   │  (fichiers partagés) │
      └────────┬────────┘                   └──────────┬───────┘
               │                                       │
               └───────────────────┬───────────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │           RADOS              │
                    │  (Reliable Autonomic         │
                    │   Distributed Object Store)  │
                    └──────────────┬──────────────┘
                                   │
         ┌─────────────────────────┼──────────────────────────┐
         │                         │                          │
┌────────▼────────┐    ┌───────────▼──────────┐   ┌──────────▼────────┐
│   OSD.0/1/2     │    │   OSD.3/4/5          │   │   OSD.6/7/8       │
│   node1         │    │   node2              │   │   node3           │
│   3 × 100 Go    │    │   3 × 100 Go         │   │   3 × 100 Go      │
└─────────────────┘    └──────────────────────┘   └───────────────────┘

  ◆ Réplication factor 3  →  chaque bloc écrit sur 3 nœuds différents
  ◆ CRUSH Map  →  distribution et équilibrage automatique des données
  ◆ Tolérance  →  perte d'1 nœud complet sans interruption de service
```

---

## 🗂 Table des matières

1. [Environnement technique](#-environnement-technique)
2. [Plan d'adressage](#-plan-dadressage)
3. [Préparation des nœuds](#1-préparation-des-nœuds)
4. [Déploiement du cluster Ceph](#3-déploiement-du-cluster-ceph)
5. [Déploiement des MON et MGR](#4-déploiement-des-mon-et-mgr)
6. [Déploiement des OSD](#5-déploiement-des-osd)
7. [Création du pool RBD](#6-création-du-pool-rbd-pour-libvirt)
8. [Intégration Ceph RBD + Libvirt](#7-intégration-ceph-rbd-avec-libvirt)
9. [Création d'une VM sur RBD](#8-création-dune-vm-sur-ceph-rbd)
10. [Live Migration KVM](#9-migration-de-vm-entre-deux-nœuds)
11. [CephFS](#10-création-et-test-de-cephfs)
12. [Montage automatique systemd](#montage-automatique-via-systemd)
13. [État final & validation](#-état-final-du-cluster)
14. [Commandes utiles](#-commandes-de-diagnostic)

---

## 🖥 Environnement technique

| Élément | Configuration |
|---|---|
| Hyperviseur hôte | VMware Workstation |
| OS des nœuds | Rocky Linux 10.1 |
| Nombre de nœuds | 3 |
| Réseau | 192.168.247.0/24 |
| Stockage OS | 50 Go par VM |
| Stockage Ceph | 3 × 100 Go par nœud (9 OSD au total) |
| Version Ceph | **Ceph 19.2.3 Squid** |
| Virtualisation | Libvirt / KVM / QEMU |
| Stockage VM | Ceph RBD |
| Système de fichiers distribué | CephFS |

---

## 🗺 Plan d'adressage

| Nœud | Adresse IP | Rôle |
|---|---|---|
| node1 | 192.168.247.101 | MON, MGR (lead), OSD, Libvirt/KVM |
| node2 | 192.168.247.102 | MON, MGR (standby), OSD, Libvirt/KVM |
| node3 | 192.168.247.103 | MON, MDS, OSD, Libvirt/KVM |

Ajouter dans `/etc/hosts` sur les 3 nœuds :

```
192.168.247.101  node1
192.168.247.102  node2
192.168.247.103  node3
```

---

## 1. Préparation des nœuds

Installation des paquets sur chaque nœud :

```bash
dnf install -y cephadm ceph libvirt qemu-kvm virt-install pcs pacemaker chrony
```

Activation des services :

```bash
systemctl enable --now chronyd
systemctl enable --now libvirtd
systemctl enable --now pcsd
```

Vérification réseau depuis node1 :

```bash
ping -c 2 node2
ping -c 2 node3
```

Vérification des disques (3 × 100 Go par nœud) :

```bash
lsblk
```

---

## 2. Vérification réseau et stockage

Les trois nœuds communiquent sur le réseau `192.168.247.0/24`. Chaque nœud dispose de trois disques de 100 Go dédiés à Ceph (`/dev/sdb`, `/dev/sdc`, `/dev/sdd`).

---

## 3. Déploiement du cluster Ceph

Bootstrap du cluster sur **node1** :

```bash
cephadm bootstrap \
  --mon-ip 192.168.247.101 \
  --initial-dashboard-user admin \
  --initial-dashboard-password <password>
```

Copie de la clé SSH vers node2 et node3, puis ajout à l'orchestrateur :

```bash
ssh-copy-id -f -i /etc/ceph/ceph.pub root@node2
ssh-copy-id -f -i /etc/ceph/ceph.pub root@node3

ceph orch host add node2 192.168.247.102
ceph orch host add node3 192.168.247.103
```

Vérification des hôtes :

```bash
ceph orch host ls
```

Résultat attendu :

```
HOST   ADDR             LABELS  STATUS
node1  192.168.247.101  _admin
node2  192.168.247.102  _admin
node3  192.168.247.103  _admin
```

---

## 4. Déploiement des MON et MGR

```bash
ceph orch apply mon --placement="3 node1 node2 node3"
ceph orch apply mgr --placement="2 node1 node2"
```

Vérification :

```bash
ceph orch ps --daemon-type mon
ceph -s
```

Quorum attendu :

```
quorum node1,node2,node3
```

---

## 5. Déploiement des OSD

Détection des disques disponibles :

```bash
ceph orch device ls
```

Création automatique des OSD sur tous les disques disponibles :

```bash
ceph orch apply osd --all-available-devices
```

Vérification :

```bash
ceph orch ps --daemon-type osd
ceph osd tree
```

Résultat obtenu :

```
9 osds: 9 up, 9 in
```

---

## 6. Création du pool RBD pour Libvirt

```bash
# pg_num = 64 pour 9 OSD avec réplication 3 (recommandation Ceph)
ceph osd pool create libvirt-pool 64 64
ceph osd pool application enable libvirt-pool rbd
rbd pool init libvirt-pool
```

Vérification :

```bash
ceph osd pool ls
rbd ls -p libvirt-pool
```

---

## 7. Intégration Ceph RBD avec Libvirt

Création de l'utilisateur Ceph dédié à Libvirt :

```bash
ceph auth get-or-create client.libvirt \
  mon 'profile rbd' \
  osd 'profile rbd pool=libvirt-pool' \
  mgr 'profile rbd pool=libvirt-pool' \
  -o /etc/ceph/ceph.client.libvirt.keyring
```

Récupération de la clé et création du secret Libvirt :

```bash
CEPH_KEY=$(ceph auth get-key client.libvirt)

cat > /tmp/secret.xml << EOF
<secret ephemeral='no' private='no'>
  <usage type='ceph'>
    <name>client.libvirt secret</name>
  </usage>
</secret>
EOF

UUID=$(virsh secret-define --file /tmp/secret.xml | grep -o '[a-f0-9-]\{36\}')
virsh secret-set-value --secret $UUID --base64 $CEPH_KEY
```

Déclaration du pool côté Libvirt :

```bash
cat > /tmp/ceph-pool.xml << EOF
<pool type='rbd'>
  <name>ceph-rbd</name>
  <source>
    <host name='node1' port='6789'/>
    <host name='node2' port='6789'/>
    <host name='node3' port='6789'/>
    <name>libvirt-pool</name>
    <auth type='ceph' username='libvirt'>
      <secret uuid='$UUID'/>
    </auth>
  </source>
</pool>
EOF

virsh pool-define /tmp/ceph-pool.xml
virsh pool-autostart ceph-rbd
virsh pool-start ceph-rbd
```

Validation :

```bash
virsh pool-list --all
virsh vol-list ceph-rbd
```

---

## 8. Création d'une VM sur Ceph RBD

Création d'un volume RBD et déploiement de la VM :

```bash
virsh vol-create-as ceph-rbd vm-ceph-demo 20G

virt-install \
  --name vm-ceph-demo \
  --memory 2048 \
  --vcpus 2 \
  --disk vol=ceph-rbd/vm-ceph-demo,bus=virtio \
  --os-variant rocky9 \
  --graphics vnc \
  --noautoconsole
```

Vérifications :

```bash
# Côté Libvirt
virsh domblklist vm-ceph-demo

# Côté Ceph
rbd ls -p libvirt-pool
```

Résultat attendu :

```
vm-ceph-demo
```

---

## 9. Migration de VM entre deux nœuds

La live migration est possible grâce au stockage RBD **partagé entre tous les nœuds**.

```bash
# Migration à chaud de node1 vers node2
virsh migrate --live --verbose vm-ceph-demo qemu+ssh://node2/system
```

Vérification post-migration :

```bash
# La VM ne doit plus apparaître sur node1
virsh list --all

# Elle doit être active sur node2
ssh root@node2 "virsh list --all"
```

> 🔑 **Prérequis** : SSH sans mot de passe entre les nœuds, accès partagé au pool RBD, même réseau.

---

## 10. Création et test de CephFS

Création du volume CephFS (cephadm crée automatiquement les pools `cephfs.cephfs.meta` et `cephfs.cephfs.data`) :

```bash
ceph fs volume create cephfs
```

Vérification des MDS et du filesystem :

```bash
ceph fs ls
ceph fs status
ceph orch ps --daemon-type mds
```

Montage manuel sur les trois nœuds :

```bash
mkdir -p /mnt/cephfs

mount -t ceph node1,node2,node3:/ /mnt/cephfs \
  -o name=cephfs,secret=<SECRET>
```

Test de validation de l'accès partagé :

```bash
# Écrire depuis node1
echo "CephFS OK depuis node1" > /mnt/cephfs/test-cephfs.txt

# Lire depuis node2 ou node3
cat /mnt/cephfs/test-cephfs.txt
```

---

## ⚙️ Montage automatique via systemd

Pour que le CephFS soit monté automatiquement au démarrage, on utilise un **unit file systemd mount**.

> Le nom du fichier doit correspondre au chemin de montage : `/mnt/cephfs` → `mnt-cephfs.mount`

### 1. Stocker la clé d'accès

```bash
ceph auth get-key client.admin > /etc/ceph/cephfs.secret
chmod 600 /etc/ceph/cephfs.secret
```

### 2. Créer le unit file

```bash
tee /etc/systemd/system/mnt-cephfs.mount << 'EOF'
[Unit]
Description=Mount CephFS on /mnt/cephfs
After=network-online.target ceph.target
Wants=network-online.target

[Mount]
What=node1,node2,node3:/
Where=/mnt/cephfs
Type=ceph
Options=name=admin,secretfile=/etc/ceph/cephfs.secret,_netdev,noatime

[Install]
WantedBy=multi-user.target
EOF
```

### 3. Activer et démarrer

```bash
systemctl daemon-reload
systemctl enable mnt-cephfs.mount
systemctl start mnt-cephfs.mount

# Vérification
systemctl status mnt-cephfs.mount
df -h /mnt/cephfs
```

---

## ✅ État final du cluster

```bash
ceph -s
ceph osd tree
ceph df
ceph orch host ls
ceph orch ps
```

| Point de validation | Statut |
|---|---|
| 3 nœuds dans le cluster | ✅ |
| 3 moniteurs en quorum | ✅ |
| 9 OSD actifs (9 up, 9 in) | ✅ |
| Pool RBD `libvirt-pool` opérationnel | ✅ |
| VM `vm-ceph-demo` stockée dans Ceph RBD | ✅ |
| Live migration validée (node1 → node2) | ✅ |
| CephFS monté sur `/mnt/cephfs` | ✅ |
| Montage automatique via systemd | ✅ |
| Libvirt configuré en mode session utilisateur | ✅ |

---

## 🔍 Commandes de diagnostic

### Santé générale

```bash
ceph -s                  # Statut global du cluster
ceph health detail       # Détail des alertes actives
ceph df                  # Utilisation du stockage
```

### Monitors et Managers

```bash
ceph mon stat            # État des monitors
ceph quorum_status       # Quorum actuel
ceph mgr stat            # Manager actif / standby
```

### OSDs

```bash
ceph osd stat            # Nombre d'OSDs up/in
ceph osd tree            # Arborescence CRUSH
ceph osd df              # Utilisation par OSD
```

### MDS / CephFS

```bash
ceph mds stat            # État des serveurs de métadonnées
ceph fs status cephfs    # Santé du filesystem
ceph fs ls               # Liste des filesystems
```

### RBD / Pools

```bash
ceph osd pool ls                        # Liste des pools
rbd ls libvirt-pool                     # Images RBD dans le pool
rbd info libvirt-pool/vm-ceph-demo      # Détails d'une image RBD
ceph osd pool get libvirt-pool pg_num   # Nombre de Placement Groups
```

---

## ⚠️ Limites du lab

Ce projet a été réalisé dans un environnement de laboratoire virtualisé. Les performances observées ne représentent pas celles d'un cluster Ceph de production.

Certaines alertes Ceph liées à BlueStore peuvent apparaître dans VMware Workstation en raison de la couche de virtualisation des disques.

---

## 📚 Références

- [Documentation officielle Ceph](https://docs.ceph.com)
- [cephadm — Orchestrateur officiel](https://docs.ceph.com/en/latest/cephadm/)
- [Ceph RBD + libvirt](https://docs.ceph.com/en/latest/rbd/libvirt/)
- [CephFS — Ceph Filesystem](https://docs.ceph.com/en/latest/cephfs/)
- [virsh migrate — KVM Live Migration](https://libvirt.org/manpages/virsh.html#migrate)
- [Systemd mount units](https://www.freedesktop.org/software/systemd/man/systemd.mount.html)

---

## 👤 Auteur

Projet réalisé par **Fréderic Junior EPESSE PRISO** dans le cadre du cursus **M2 — Virtualisation et clustering d'infrastructure** (2025-2026).  
Encadrant : Kevin Chevreuil

---

*Lab reproductible sur VMware Workstation avec 3 VMs Rocky Linux 10.1 — Ceph 19.2.3 Squid.*
