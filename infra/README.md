# 🏗️ Infrastructure Management

Ce répertoire contient tous les outils et scripts pour gérer l'infrastructure AWS de votre Chatbot Analytique MongoDB Movies.

## 📁 Structure

```
infra/
├── README.md              # Ce fichier
├── deploy_ec2.sh          # Script de déploiement automatique EC2
├── manage_ec2.sh          # Gestion start/stop/status de l'instance  
├── setup_aws.sh           # Configuration initiale AWS CLI
├── elastic_ip.sh          # Gestion de l'Elastic IP
├── backup_instance.sh     # Sauvegarde et snapshot
├── monitoring.sh          # Surveillance et logs
└── DEPLOYMENT_AWS.md      # Guide complet de déploiement
```

## 🚀 Quick Start

### 1. Configuration Initiale
```bash
# Configuration AWS CLI
cd infra
./setup_aws.sh

# Déploiement sur EC2
./deploy_ec2.sh
```

### 2. Gestion Quotidienne  
```bash
# Interface de gestion
./manage_ec2.sh

# Surveillance
./monitoring.sh

# Sauvegarde
./backup_instance.sh
```

## 🔧 Scripts Disponibles

### `deploy_ec2.sh`
- **Usage** : Déploiement initial sur nouvelle instance EC2
- **Prérequis** : Instance EC2 Ubuntu créée
- **Action** : Installation complète + configuration services

### `manage_ec2.sh` 
- **Usage** : Gestion start/stop/restart de l'instance
- **Économies** : ~$5-10/mois avec arrêts réguliers
- **Interface** : Menu interactif

### `setup_aws.sh`
- **Usage** : Configuration initiale AWS CLI + permissions
- **Action** : Validation des credentials et région

### `elastic_ip.sh`
- **Usage** : Allocation et gestion d'IP fixe
- **Coût** : ~$3.60/mois pour IP statique

### `backup_instance.sh`
- **Usage** : Création de snapshots EBS automatiques
- **Sécurité** : Sauvegarde avant mises à jour

### `monitoring.sh`
- **Usage** : Surveillance CPU/RAM/Disk/Logs
- **Alertes** : Notification si problèmes détectés

## 💰 Gestion des Coûts

### Coûts par Composant
```
t3.small (2 vCPU, 2GB)     : ~$15-20/mois
Stockage EBS (20GB)        : ~$2/mois  
Elastic IP (optionnel)     : ~$3.60/mois
Snapshots (optionnel)      : ~$1-3/mois
```

### Optimisations
- **Stop/Start quotidien** : -$5/mois
- **Reserved Instance** : -30% si usage continu
- **Monitoring gratuit** : CloudWatch Basic

## 🔒 Sécurité

### Bonnes Pratiques Implémentées
- ✅ Utilisateur dédié (non-root)
- ✅ Firewall configuré (UFW)
- ✅ HTTPS via Nginx
- ✅ Variables d'environnement sécurisées
- ✅ Logs centralisés