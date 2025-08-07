#!/bin/bash
# Script de gestion EC2 pour le chatbot MongoDB Movies

# Configuration - REMPLACEZ PAR VOS VALEURS
INSTANCE_ID="i-1234567890abcdef0"  # Votre Instance ID
INSTANCE_NAME="mbot-chatbot"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher l'état de l'instance
check_status() {
    echo -e "${BLUE}🔍 Vérification de l'état de l'instance...${NC}"
    
    STATUS=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Erreur: Impossible de récupérer l'état de l'instance${NC}"
        echo "Vérifiez votre INSTANCE_ID et configuration AWS CLI"
        exit 1
    fi
    
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text 2>/dev/null)
    
    echo -e "${BLUE}📊 Instance: ${INSTANCE_NAME} (${INSTANCE_ID})${NC}"
    echo -e "${BLUE}📍 État: ${STATUS}${NC}"
    
    if [ "$STATUS" = "running" ] && [ "$PUBLIC_IP" != "None" ]; then
        echo -e "${GREEN}🌐 IP Publique: ${PUBLIC_IP}${NC}"
        echo -e "${GREEN}🎬 Application: http://${PUBLIC_IP}${NC}"
    elif [ "$STATUS" = "running" ]; then
        echo -e "${YELLOW}⏳ Instance en démarrage... IP pas encore assignée${NC}"
    fi
}

# Fonction pour arrêter l'instance
stop_instance() {
    echo -e "${YELLOW}🛑 Arrêt de l'instance EC2...${NC}"
    
    aws ec2 stop-instances --instance-ids $INSTANCE_ID >/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Commande d'arrêt envoyée avec succès${NC}"
        echo -e "${BLUE}⏳ Attente de l'arrêt complet...${NC}"
        
        # Attendre que l'instance soit complètement arrêtée
        aws ec2 wait instance-stopped --instance-ids $INSTANCE_ID
        echo -e "${GREEN}✅ Instance arrêtée avec succès${NC}"
        echo -e "${YELLOW}💰 Facturation arrêtée (seul le stockage EBS reste facturé)${NC}"
    else
        echo -e "${RED}❌ Erreur lors de l'arrêt de l'instance${NC}"
    fi
}

# Fonction pour démarrer l'instance
start_instance() {
    echo -e "${GREEN}🚀 Démarrage de l'instance EC2...${NC}"
    
    aws ec2 start-instances --instance-ids $INSTANCE_ID >/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Commande de démarrage envoyée avec succès${NC}"
        echo -e "${BLUE}⏳ Attente du démarrage complet...${NC}"
        
        # Attendre que l'instance soit complètement démarrée
        aws ec2 wait instance-running --instance-ids $INSTANCE_ID
        
        # Récupérer la nouvelle IP
        NEW_IP=$(aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)
        
        echo -e "${GREEN}✅ Instance démarrée avec succès${NC}"
        echo -e "${GREEN}🌐 Nouvelle IP publique: ${NEW_IP}${NC}"
        echo -e "${GREEN}🎬 Application disponible sur: http://${NEW_IP}${NC}"
        echo -e "${BLUE}⏳ Attendez ~2-3 minutes que tous les services démarrent${NC}"
    else
        echo -e "${RED}❌ Erreur lors du démarrage de l'instance${NC}"
    fi
}

# Fonction pour redémarrer l'instance
restart_instance() {
    echo -e "${YELLOW}🔄 Redémarrage de l'instance EC2...${NC}"
    stop_instance
    echo -e "${BLUE}⏳ Attente de 10 secondes...${NC}"
    sleep 10
    start_instance
}

# Menu principal
show_menu() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}🎬 Gestionnaire EC2 - Chatbot MongoDB Movies${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    echo "1) 🔍 Vérifier l'état"
    echo "2) 🚀 Démarrer l'instance"
    echo "3) 🛑 Arrêter l'instance"
    echo "4) 🔄 Redémarrer l'instance"
    echo "5) 📊 Coûts estimés"
    echo "0) ❌ Quitter"
    echo ""
}

# Fonction d'estimation des coûts
show_costs() {
    echo -e "${BLUE}💰 Estimation des Coûts EC2 t3.small${NC}"
    echo "=================================="
    echo "Instance en marche: ~$0.0208/heure"
    echo "Instance arrêtée: $0.00/heure"
    echo "Stockage EBS (20GB): ~$2/mois"
    echo ""
    echo "📊 Économies par arrêt:"
    echo "• 1 jour arrêtée: ~$0.50 économisé"  
    echo "• 1 semaine arrêtée: ~$3.50 économisé"
    echo "• Nuits (8h/jour): ~$5/mois économisé"
    echo ""
}

# Configuration initiale
if [ "$INSTANCE_ID" = "i-1234567890abcdef0" ]; then
    echo -e "${RED}⚠️  CONFIGURATION REQUISE${NC}"
    echo "Veuillez modifier ce script et remplacer:"
    echo "INSTANCE_ID par votre vrai Instance ID"
    echo ""
    echo "Pour trouver votre Instance ID:"
    echo "aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==\`Name\`].Value|[0],State.Name]' --output table"
    exit 1
fi

# Vérifier AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI non trouvé${NC}"
    echo "Installez AWS CLI et configurez vos credentials"
    exit 1
fi

# Boucle du menu principal
while true; do
    show_menu
    read -p "Choisissez une option: " choice
    echo ""
    
    case $choice in
        1) check_status ;;
        2) start_instance ;;
        3) stop_instance ;;
        4) restart_instance ;;
        5) show_costs ;;
        0) echo -e "${GREEN}👋 Au revoir !${NC}"; exit 0 ;;
        *) echo -e "${RED}❌ Option invalide${NC}" ;;
    esac
    
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
    echo ""
done