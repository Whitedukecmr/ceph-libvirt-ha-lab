# Ceph Libvirt HA Lab



Projet de déploiement d’un cluster Ceph sur 3 nœuds Rocky Linux, avec intégration Libvirt/KVM, stockage RBD, CephFS et validation de la migration de machines virtuelles.



Ce laboratoire a été réalisé dans un environnement virtualisé VMware Workstation. L’objectif est de reproduire une architecture de stockage distribué proche d’un contexte professionnel, en mettant l’accent sur la haute disponibilité, la supervision de l’état du cluster, l’intégration avec Libvirt et l’exploitation de volumes RBD pour héberger des machines virtuelles.



\---



\## Objectifs du projet



Ce projet couvre les points suivants :



\- Déploiement d’un cluster Ceph 3 nœuds avec `cephadm`

\- Configuration des services MON, MGR, MDS et OSD

\- Création d’un pool RBD dédié à Libvirt

\- Intégration du stockage Ceph RBD dans Libvirt

\- Création et démarrage d’une VM stockée sur Ceph RBD

\- Migration d’une VM entre deux nœuds KVM

\- Création et montage d’un système de fichiers CephFS

\- Configuration de Libvirt en mode session utilisateur

\- Validation de l’accès au stockage depuis plusieurs nœuds



\---



\## Architecture du lab



```text

&#x20;                        +----------------------+

&#x20;                        |   VMware Workstation |

&#x20;                        +----------+-----------+

&#x20;                                   |

&#x20;                        Réseau NAT / Bridge Lab

&#x20;                                   |

&#x20;       +---------------------------+---------------------------+

&#x20;       |                           |                           |

+-------+--------+          +-------+--------+          +-------+--------+

|    node1       |          |    node2       |          |    node3       |

| 192.168.247.101|          | 192.168.247.102|          | 192.168.247.103|

| Rocky Linux    |          | Rocky Linux    |          | Rocky Linux    |

| Ceph MON/MGR   |          | Ceph MON/MGR   |          | Ceph MON/MDS   |

| Libvirt/KVM    |          | Libvirt/KVM    |          | Libvirt/KVM    |

| 3 OSD          |          | 3 OSD          |          | 3 OSD          |

+-------+--------+          +-------+--------+          +-------+--------+

&#x20;       |                           |                           |

&#x20;       +---------------------------+---------------------------+

&#x20;                                   |

&#x20;                           Cluster Ceph

&#x20;                   RBD pool + CephFS + monitoring

