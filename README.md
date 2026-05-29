# Ceph Libvirt HA Lab

Déploiement d’un cluster Ceph 3 nœuds avec stockage distribué RBD, CephFS et intégration Libvirt/KVM en environnement VMware Workstation.

Ce projet présente la mise en place d’un laboratoire de stockage distribué basé sur Ceph.  
L’objectif est de construire une infrastructure proche d’un contexte professionnel, avec plusieurs nœuds Rocky Linux, des disques dédiés aux OSD, un stockage RBD utilisé par Libvirt/KVM, un système de fichiers CephFS partagé et une validation de migration de machine virtuelle.

---

## Objectifs du projet

Ce lab permet de valider les points suivants :

- Déploiement d’un cluster Ceph 3 nœuds avec `cephadm`
- Configuration des services Ceph : MON, MGR, MDS et OSD
- Ajout de plusieurs disques OSD par nœud
- Création d’un pool RBD dédié à Libvirt
- Intégration de Ceph RBD comme backend de stockage Libvirt/KVM
- Création d’une machine virtuelle stockée sur Ceph RBD
- Migration d’une VM entre deux nœuds KVM
- Création et montage d’un système de fichiers CephFS
- Configuration de Libvirt en mode session utilisateur
- Validation de l’accès au stockage depuis plusieurs nœuds

---

## Architecture du lab

```text
                       +----------------------+
                       |   VMware Workstation |
                       +----------+-----------+
                                  |
                         Réseau lab 192.168.247.0/24
                                  |
        +-------------------------+-------------------------+
        |                         |                         |
+-------+--------+        +-------+--------+        +-------+--------+
|     node1      |        |     node2      |        |     node3      |
| 192.168.247.101|        | 192.168.247.102|        | 192.168.247.103|
| Rocky Linux    |        | Rocky Linux    |        | Rocky Linux    |
| Ceph MON/MGR   |        | Ceph MON/MGR   |        | Ceph MON/MDS   |
| Libvirt/KVM    |        | Libvirt/KVM    |        | Libvirt/KVM    |
| 3 OSD          |        | 3 OSD          |        | 3 OSD          |
+-------+--------+        +-------+--------+        +-------+--------+
        |                         |                         |
        +-------------------------+-------------------------+
                                  |
                         Cluster Ceph distribué
                         RBD + CephFS + Libvirt
---

## Environnement technique

| Élément                       | Configuration                |
| ----------------------------- | ---------------------------- |
| Hyperviseur hôte              | VMware Workstation           |
| OS des nœuds                  | Rocky Linux 10.1             |
| Nombre de nœuds               | 3                            |
| Réseau                        | 192.168.247.0/24             |
| Stockage OS                   | 50 Go par VM                 |
| Stockage Ceph                 | 3 disques de 100 Go par nœud |
| Version Ceph                  | Ceph 19.2.3 Squid            |
| Virtualisation                | Libvirt / KVM / QEMU         |
| Stockage VM                   | Ceph RBD                     |
| Système de fichiers distribué | CephFS                       |

---

## Plan d’adressage

| Nœud  | Adresse IP      | Rôle                               |
| ----- | --------------- | ---------------------------------- |
| node1 | 192.168.247.101 | MON, MGR, OSD, Libvirt/KVM         |
| node2 | 192.168.247.102 | MON, MGR standby, OSD, Libvirt/KVM |
| node3 | 192.168.247.103 | MON, MDS, OSD, Libvirt/KVM         |

---

## Étapes réalisées

### 1. Préparation des nœuds

Chaque nœud Rocky Linux a été préparé avec les paquets nécessaires :

```bash
dnf install -y cephadm ceph libvirt qemu-kvm virt-install pcs pacemaker chrony
```

Les services nécessaires ont ensuite été activés :

```bash
systemctl enable --now chronyd
systemctl enable --now libvirtd
systemctl enable --now pcsd
```

---

### 2. Vérification réseau et stockage

Les trois nœuds communiquent sur le réseau `192.168.247.0/24`.

Exemple de vérification depuis `node1` :

```bash
ping -c 2 node2
ping -c 2 node3
```

Chaque nœud dispose de trois disques de 100 Go utilisés pour Ceph :

```bash
lsblk
```

---

### 3. Déploiement du cluster Ceph

Le cluster Ceph a été initialisé avec `cephadm`, puis les nœuds `node2` et `node3` ont été ajoutés à l’orchestrateur.

Vérification des hôtes :

```bash
ceph orch host ls
```

Résultat attendu :

```text
HOST   ADDR             LABELS  STATUS
node1  192.168.247.101  _admin
node2  192.168.247.102  _admin
node3  192.168.247.103  _admin
```

---

### 4. Déploiement des MON et MGR

Les moniteurs Ceph ont été déployés sur les trois nœuds :

```bash
ceph orch apply mon --placement="3 node1 node2 node3"
```

Vérification :

```bash
ceph orch ps --daemon-type mon
ceph -s
```

Le quorum attendu est :

```text
quorum node1,node2,node3
```

---

### 5. Déploiement des OSD

Les disques disponibles ont été détectés avec :

```bash
ceph orch device ls
```

Puis les OSD ont été créés automatiquement :

```bash
ceph orch apply osd --all-available-devices
```

Vérification :

```bash
ceph orch ps --daemon-type osd
ceph osd tree
```

Résultat obtenu :

```text
9 osds: 9 up, 9 in
```

---

### 6. Création du pool RBD pour Libvirt

Un pool RBD dédié à Libvirt a été créé :

```bash
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

### 7. Intégration Ceph RBD avec Libvirt

Un utilisateur Ceph dédié à Libvirt a été créé :

```bash
ceph auth get-or-create client.libvirt \
  mon 'profile rbd' \
  osd 'profile rbd pool=libvirt-pool' \
  mgr 'profile rbd pool=libvirt-pool' \
  -o /etc/ceph/ceph.client.libvirt.keyring
```

Le pool Ceph RBD a ensuite été déclaré côté Libvirt.

Validation :

```bash
virsh pool-list --all
virsh vol-list ceph-rbd
```

---

### 8. Création d’une VM sur Ceph RBD

Une machine virtuelle a été créée avec son disque stocké directement dans le pool RBD `libvirt-pool`.

Vérification côté Libvirt :

```bash
virsh domblklist vm-ceph-demo
```

Vérification côté Ceph :

```bash
rbd ls -p libvirt-pool
```

Résultat attendu :

```text
vm-ceph-demo
```

---

### 9. Migration de VM entre deux nœuds

La VM `vm-ceph-demo` a été migrée de `node1` vers `node2`.

Commande utilisée :

```bash
virsh migrate --live --verbose vm-ceph-demo qemu+ssh://node2/system
```

Vérification :

```bash
virsh list --all
ssh root@node2 "virsh list --all"
```

La VM apparaît ensuite en cours d’exécution sur `node2`.

---

### 10. Création et test de CephFS

Un volume CephFS a été créé :

```bash
ceph fs volume create cephfs
```

Vérification :

```bash
ceph fs ls
ceph fs status
ceph orch ps --daemon-type mds
```

Le système de fichiers a été monté sur les trois nœuds :

```bash
mount -t ceph node1,node2,node3:/ /mnt/cephfs -o name=cephfs,secret=<SECRET>
```

Test de validation :

```bash
echo "CephFS OK depuis node1" > /mnt/cephfs/test-cephfs.txt
cat /mnt/cephfs/test-cephfs.txt
```

---

## Configuration Libvirt en mode session

Dans le cadre du projet, Libvirt a également été configuré en mode session utilisateur.

Objectif attendu :

```bash
virsh uri
```

Résultat :

```text
qemu:///session
```

Le pool RBD Ceph a aussi été déclaré dans la session utilisateur `rocky` sur les trois nœuds.

Vérification :

```bash
virsh pool-list --all
virsh vol-list ceph-rbd
```

---

## État final du cluster

Commandes de validation :

```bash
ceph -s
ceph osd tree
ceph df
ceph orch host ls
ceph orch ps
```

État obtenu :

* 3 nœuds dans le cluster
* 3 moniteurs en quorum
* 9 OSD actifs
* 1 pool RBD dédié à Libvirt
* 1 volume CephFS fonctionnel
* VM stockée dans Ceph RBD
* Migration de VM validée entre deux nœuds
* Libvirt configuré en mode session utilisateur

---

## Points importants observés

Ce projet montre plusieurs compétences utiles en environnement système, virtualisation et stockage :

* Administration Linux
* Déploiement Ceph avec `cephadm`
* Gestion d’un stockage distribué
* Configuration de Libvirt/KVM
* Intégration RBD avec Libvirt
* Utilisation de CephFS
* Diagnostic réseau et stockage
* Validation de migration de VM
* Travail sur un environnement multi-nœuds

---

## Limites du lab

Ce projet a été réalisé dans un environnement de laboratoire virtualisé.
Les performances observées ne représentent donc pas celles d’un cluster Ceph de production.

Certaines alertes Ceph liées à BlueStore peuvent apparaître dans VMware Workstation, notamment à cause des disques virtuels et de la couche de virtualisation.

---

## Auteur

Projet réalisé par Fréderic Junior EPESSE PRISO dans le cadre d’un laboratoire système, virtualisation et stockage distribué.


