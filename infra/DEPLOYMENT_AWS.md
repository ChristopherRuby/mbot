# 🚀 Guide de Déploiement AWS EC2

Guide complet pour déployer le Chatbot Analytique MongoDB Movies sur AWS EC2.

## 💰 Coût Estimé
- **Instance t3.micro** : ~$8-12/mois (1 vCPU, 1GB RAM)
- **Instance t3.small** : ~$15-20/mois (2 vCPU, 2GB RAM) - **Recommandée**

## 📋 Prérequis

### 1. Compte AWS
- Accès à la console AWS
- Carte de crédit pour les frais

### 2. Clés API
- ✅ Clé API Perplexity fonctionnelle
- ✅ URI MongoDB Atlas configuré
- ✅ Repository GitHub avec le code poussé

## 🖥️ Étape 1 : Créer l'Instance EC2

### 1.1 Lancer une Instance
1. Connectez-vous à la **Console AWS**
2. Allez dans **EC2 → Launch Instance**
3. **Configuration recommandée** :
   - **Nom** : `mbot-chatbot`
   - **AMI** : Ubuntu Server 22.04 LTS
   - **Type d'instance** : `t3.small` (recommandé) ou `t3.micro` (économique)
   - **Paire de clés** : Créez une nouvelle paire ou utilisez existante
   - **Stockage** : 20 GB gp3 (par défaut)

### 1.2 Configuration du Groupe de Sécurité
**Créez un nouveau groupe de sécurité avec :**
- **Port 22** (SSH) : Votre IP seulement
- **Port 80** (HTTP) : 0.0.0.0/0 (tout Internet)
- **Port 443** (HTTPS) : 0.0.0.0/0 (tout Internet) - Optionnel

### 1.3 Lancer l'Instance
- Cliquez sur **"Launch Instance"**
- **Notez l'adresse IP publique** de votre instance

## 🔐 Étape 2 : Connexion SSH

### 2.1 Se Connecter à l'Instance
```bash
# Remplacez YOUR_KEY.pem et YOUR_IP par vos valeurs
ssh -i "YOUR_KEY.pem" ubuntu@YOUR_IP
```

### 2.2 Première Connexion
```bash
# Mise à jour initiale
sudo apt update
```

## 📥 Étape 3 : Déploiement Automatique

### 3.1 Télécharger et Exécuter le Script
```bash
# Télécharger le script de déploiement
wget https://raw.githubusercontent.com/VOTRE_USERNAME/VOTRE_REPO/main/deploy_ec2.sh

# Rendre exécutable
chmod +x deploy_ec2.sh

# Exécuter (attention: remplacez les URLs par les vôtres)
sudo ./deploy_ec2.sh
```

### 3.2 Configuration des Variables d'Environnement
```bash
# Éditer le fichier .env avec vos vraies clés
sudo nano /home/mbot/app/.env
```

**Contenu du fichier .env :**
```env
PERPLEXITY_API_KEY=votre_vraie_cle_perplexity
MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/
MONGODB_DATABASE=sample_mflix
MONGODB_COLLECTION=movies
```

## 🚀 Étape 4 : Démarrage des Services

### 4.1 Démarrer l'Application
```bash
# Démarrer le service du chatbot
sudo systemctl start mbot

# Démarrer Nginx
sudo systemctl start nginx

# Vérifier le statut
sudo systemctl status mbot
sudo systemctl status nginx
```

### 4.2 Test de l'Application
```bash
# Tester en local
curl http://localhost

# Vérifier les logs
sudo journalctl -u mbot -f
```

## 🌐 Étape 5 : Accès à votre Application

### 5.1 Accès Web
- **URL** : `http://VOTRE_IP_PUBLIQUE_EC2`
- **Exemple** : `http://54.123.45.67`

### 5.2 Vérification
- ✅ Interface Streamlit s'affiche
- ✅ Connexion MongoDB fonctionne
- ✅ API Perplexity répond
- ✅ Questions d'exemple fonctionnent

## 🔧 Gestion et Maintenance

### Commandes Utiles
```bash
# Redémarrer l'application
sudo systemctl restart mbot

# Voir les logs
sudo journalctl -u mbot -f

# Arrêter/Démarrer
sudo systemctl stop mbot
sudo systemctl start mbot

# Mettre à jour le code
cd /home/mbot/app
sudo -u mbot git pull
sudo systemctl restart mbot
```

### Surveillance
```bash
# Utilisation CPU/RAM
htop

# Espace disque
df -h

# Statut des services
sudo systemctl status mbot nginx
```

## 🔒 Sécurité (Optionnel mais Recommandé)

### 1. Certificat SSL Gratuit avec Let's Encrypt
```bash
# Installer Certbot
sudo apt install certbot python3-certbot-nginx

# Obtenir un certificat (nécessite un nom de domaine)
sudo certbot --nginx -d votre-domaine.com
```

### 2. Firewall
```bash
# Configurer UFW
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw --force enable
```

## 💡 Optimisations Performances

### Pour Plus de Trafic
- **Upgrade vers t3.medium** : 2 vCPU, 4GB RAM (~$30/mois)
- **Load Balancer** : Pour haute disponibilité
- **CloudFront** : CDN pour cache statique

## 🆘 Dépannage

### L'application ne démarre pas
```bash
# Vérifier les logs d'erreur
sudo journalctl -u mbot -n 50

# Tester manuellement
cd /home/mbot/app
sudo -u mbot ./venv/bin/streamlit run app.py
```

### Problèmes de connexion
```bash
# Vérifier Nginx
sudo nginx -t
sudo systemctl status nginx

# Vérifier les ports
sudo netstat -tlnp | grep :8501
sudo netstat -tlnp | grep :80
```

### Problèmes MongoDB/Perplexity
```bash
# Vérifier les variables d'environnement
sudo -u mbot cat /home/mbot/app/.env

# Tester les connexions
cd /home/mbot/app
sudo -u mbot ./venv/bin/python test_app.py
```

## 💰 Gestion des Coûts

### Surveillance
- **CloudWatch** : Monitoring gratuit
- **AWS Cost Explorer** : Suivi des coûts
- **Billing Alerts** : Alertes de dépassement

### Économies
- **Arrêter l'instance** quand pas utilisée
- **Reserved Instances** : -30% si usage continu
- **Spot Instances** : -70% mais peut être interrompue

---

## 🎉 Félicitations !

Votre **Chatbot Analytique MongoDB Movies** est maintenant déployé sur AWS EC2 !

**URL d'accès :** `http://VOTRE_IP_EC2`

### Support
Pour toute question, consultez les logs avec :
```bash
sudo journalctl -u mbot -f
```