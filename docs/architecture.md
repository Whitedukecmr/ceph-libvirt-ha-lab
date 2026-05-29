# Architecture technique — Ceph Libvirt HA Lab

## Topologie réseau

| Noeud | IP              | Rôles                          |
|-------|-----------------|--------------------------------|
| node1 | 192.168.247.101 | MON, MGR (lead), OSD, KVM      |
| node2 | 192.168.247.102 | MON, MGR (standby), OSD, KVM   |
| node3 | 192.168.247.103 | MON, MDS, OSD, KVM             |

## Stockage

- 3 nœuds × 3 disques × 100 Go = **900 Go brut**
- Réplication factor 3 → **~300 Go utilisables**
- Pool RBD : pg_num 64
- CephFS : pools meta + data créés automatiquement par cephadm

## Services Ceph

| Service | Nœuds         | Rôle                              |
|---------|---------------|-----------------------------------|
| MON     | node1/2/3     | Quorum et carte du cluster        |
| MGR     | node1/2       | Dashboard, métriques, orchestration|
| OSD     | node1/2/3 ×3  | Stockage des données              |
| MDS     | node3         | Métadonnées CephFS                |

## Décisions techniques

- **cephadm** choisi comme orchestrateur (méthode officielle Ceph Squid)
- **pg_num 64** pour libvirt-pool (recommandation Ceph pour 9 OSD, rep 3)
- **systemd mount unit** pour le montage CephFS (plus fiable que /etc/fstab)
- **client.libvirt** : utilisateur Ceph dédié avec droits limités au pool RBD
