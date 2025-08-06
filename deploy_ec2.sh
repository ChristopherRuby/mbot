#!/bin/bash
# Script d'installation automatique pour EC2 Ubuntu
# Déploiement du Chatbot Analytique MongoDB Movies

set -e  # Arrêter le script en cas d'erreur

echo "🚀 Déploiement du Chatbot MongoDB Movies sur EC2"
echo "================================================="

# Mise à jour du système
echo "📦 Mise à jour du système Ubuntu..."
sudo apt update && sudo apt upgrade -y

# Installation de Python 3.11 et pip
echo "🐍 Installation de Python 3.11..."
sudo apt install -y python3.11 python3.11-venv python3-pip git nginx

# Création d'un utilisateur pour l'application
echo "👤 Configuration de l'utilisateur d'application..."
sudo useradd -m -s /bin/bash mbot || echo "Utilisateur mbot existe déjà"

# Cloner le repository
echo "📥 Clonage du repository..."
cd /home/mbot
sudo -u mbot git clone https://github.com/VOTRE_USERNAME/VOTRE_REPO.git app || echo "Repository déjà cloné"
cd app

# Création de l'environnement virtuel
echo "🔧 Création de l'environnement virtuel..."
sudo -u mbot python3.11 -m venv venv
sudo -u mbot ./venv/bin/pip install --upgrade pip
sudo -u mbot ./venv/bin/pip install -r requirements.txt

# Configuration des variables d'environnement
echo "⚙️ Configuration des variables d'environnement..."
sudo -u mbot tee .env > /dev/null << EOF
# Configuration pour le chatbot MongoDB Movies
PERPLEXITY_API_KEY=VOTRE_CLE_API_PERPLEXITY
MONGODB_URI=VOTRE_CHAINE_CONNEXION_MONGODB
MONGODB_DATABASE=sample_mflix
MONGODB_COLLECTION=movies
EOF

echo "⚠️  IMPORTANT: Éditez le fichier .env avec vos vraies clés API !"
echo "   sudo nano /home/mbot/app/.env"

# Configuration du service systemd
echo "🔄 Configuration du service systemd..."
sudo tee /etc/systemd/system/mbot.service > /dev/null << EOF
[Unit]
Description=Chatbot MongoDB Movies Streamlit App
After=network.target

[Service]
Type=simple
User=mbot
Group=mbot
WorkingDirectory=/home/mbot/app
Environment="PATH=/home/mbot/app/venv/bin"
ExecStart=/home/mbot/app/venv/bin/streamlit run app.py --server.port=8501 --server.address=0.0.0.0 --server.headless=true
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Configuration de Nginx comme reverse proxy
echo "🌐 Configuration de Nginx..."
sudo tee /etc/nginx/sites-available/mbot > /dev/null << EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:8501;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
    }
}
EOF

# Activation de la configuration Nginx
sudo ln -sf /etc/nginx/sites-available/mbot /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

# Activation des services
echo "🔄 Activation des services..."
sudo systemctl daemon-reload
sudo systemctl enable mbot
sudo systemctl enable nginx

echo ""
echo "✅ Installation terminée !"
echo ""
echo "🔧 ÉTAPES SUIVANTES OBLIGATOIRES :"
echo "1. Éditez le fichier .env avec vos vraies clés :"
echo "   sudo nano /home/mbot/app/.env"
echo ""
echo "2. Démarrez les services :"
echo "   sudo systemctl start mbot"
echo "   sudo systemctl start nginx"
echo ""
echo "3. Vérifiez le statut :"
echo "   sudo systemctl status mbot"
echo ""
echo "4. Consultez les logs si nécessaire :"
echo "   sudo journalctl -u mbot -f"
echo ""
echo "🌐 Votre application sera accessible sur http://IP_DE_VOTRE_EC2"