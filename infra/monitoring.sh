#!/bin/bash
# Script de monitoring pour l'instance EC2 mbot

# Configuration - REMPLACEZ PAR VOS VALEURS
INSTANCE_ID="i-1234567890abcdef0"  # Votre Instance ID
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_RAM=85
ALERT_THRESHOLD_DISK=85

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fonction pour vérifier l'état de l'instance
check_instance_status() {
    echo -e "${BLUE}🔍 État de l'instance EC2${NC}"
    echo "================================"
    
    if [ "$INSTANCE_ID" = "i-1234567890abcdef0" ]; then
        echo -e "${RED}⚠️  Configurez d'abord INSTANCE_ID dans le script${NC}"
        return 1
    fi
    
    STATUS=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Impossible de récupérer l'état de l'instance${NC}"
        return 1
    fi
    
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text 2>/dev/null)
    
    case $STATUS in
        "running")
            echo -e "${GREEN}✅ Instance: ACTIVE${NC}"
            if [ "$PUBLIC_IP" != "None" ] && [ -n "$PUBLIC_IP" ]; then
                echo -e "${GREEN}🌐 IP Publique: $PUBLIC_IP${NC}"
                echo -e "${GREEN}🎬 Application: http://$PUBLIC_IP${NC}"
            fi
            return 0
            ;;
        "stopped")
            echo -e "${YELLOW}🛑 Instance: ARRÊTÉE${NC}"
            echo "Démarrez avec ./manage_ec2.sh"
            return 1
            ;;
        "stopping")
            echo -e "${YELLOW}⏳ Instance: EN COURS D'ARRÊT${NC}"
            return 1
            ;;
        "pending")
            echo -e "${YELLOW}⏳ Instance: EN DÉMARRAGE${NC}"
            return 1
            ;;
        *)
            echo -e "${RED}❓ Instance: État inconnu ($STATUS)${NC}"
            return 1
            ;;
    esac
}

# Fonction pour vérifier les métriques via SSH
check_remote_metrics() {
    if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" = "None" ]; then
        echo -e "${RED}❌ Pas d'IP publique disponible${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${BLUE}📊 Métriques du serveur${NC}"
    echo "========================="
    
    # Vérifier si on peut se connecter
    if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP "echo 'SSH OK'" &>/dev/null; then
        echo -e "${RED}❌ Impossible de se connecter en SSH${NC}"
        echo "Vérifiez votre clé SSH et les groupes de sécurité"
        return 1
    fi
    
    # CPU Usage
    CPU_USAGE=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
        "top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\([0-9.]*\)%* id.*/\1/' | awk '{print 100 - \$1}'")
    
    if (( $(echo "$CPU_USAGE > $ALERT_THRESHOLD_CPU" | bc -l) )); then
        echo -e "${RED}🔥 CPU: ${CPU_USAGE}% (CRITIQUE)${NC}"
    elif (( $(echo "$CPU_USAGE > 60" | bc -l) )); then
        echo -e "${YELLOW}⚠️  CPU: ${CPU_USAGE}% (ÉLEVÉ)${NC}"
    else
        echo -e "${GREEN}✅ CPU: ${CPU_USAGE}%${NC}"
    fi
    
    # RAM Usage
    RAM_INFO=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
        "free | grep Mem | awk '{printf \"%.0f %.0f\", \$3/\$2 * 100.0, \$2/1024/1024}'")
    
    RAM_PERCENT=$(echo $RAM_INFO | cut -d' ' -f1)
    RAM_TOTAL=$(echo $RAM_INFO | cut -d' ' -f2)
    
    if (( $(echo "$RAM_PERCENT > $ALERT_THRESHOLD_RAM" | bc -l) )); then
        echo -e "${RED}🔥 RAM: ${RAM_PERCENT}% de ${RAM_TOTAL}GB (CRITIQUE)${NC}"
    elif (( $(echo "$RAM_PERCENT > 70" | bc -l) )); then
        echo -e "${YELLOW}⚠️  RAM: ${RAM_PERCENT}% de ${RAM_TOTAL}GB (ÉLEVÉ)${NC}"
    else
        echo -e "${GREEN}✅ RAM: ${RAM_PERCENT}% de ${RAM_TOTAL}GB${NC}"
    fi
    
    # Disk Usage
    DISK_USAGE=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
        "df -h / | tail -1 | awk '{print \$5}' | sed 's/%//'")
    
    if (( $DISK_USAGE > $ALERT_THRESHOLD_DISK )); then
        echo -e "${RED}🔥 Disque: ${DISK_USAGE}% (CRITIQUE)${NC}"
    elif (( $DISK_USAGE > 70 )); then
        echo -e "${YELLOW}⚠️  Disque: ${DISK_USAGE}% (ÉLEVÉ)${NC}"
    else
        echo -e "${GREEN}✅ Disque: ${DISK_USAGE}%${NC}"
    fi
}

# Fonction pour vérifier les services
check_services() {
    if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" = "None" ]; then
        return 1
    fi
    
    echo ""
    echo -e "${BLUE}🔄 État des services${NC}"
    echo "===================="
    
    # Service mbot
    MBOT_STATUS=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
        "sudo systemctl is-active mbot" 2>/dev/null)
    
    if [ "$MBOT_STATUS" = "active" ]; then
        echo -e "${GREEN}✅ Service mbot: ACTIF${NC}"
    else
        echo -e "${RED}❌ Service mbot: $MBOT_STATUS${NC}"
    fi
    
    # Service nginx
    NGINX_STATUS=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
        "sudo systemctl is-active nginx" 2>/dev/null)
    
    if [ "$NGINX_STATUS" = "active" ]; then
        echo -e "${GREEN}✅ Service nginx: ACTIF${NC}"
    else
        echo -e "${RED}❌ Service nginx: $NGINX_STATUS${NC}"
    fi
    
    # Test HTTP
    if curl -s --max-time 10 "http://$PUBLIC_IP" >/dev/null; then
        echo -e "${GREEN}✅ Application web: ACCESSIBLE${NC}"
    else
        echo -e "${RED}❌ Application web: INACCESSIBLE${NC}"
    fi
}

# Fonction pour afficher les logs
show_logs() {
    if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" = "None" ]; then
        return 1
    fi
    
    echo ""
    echo -e "${BLUE}📜 Derniers logs (10 lignes)${NC}"
    echo "============================="
    
    echo -e "${YELLOW}--- Logs mbot ---${NC}"
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
        "sudo journalctl -u mbot -n 10 --no-pager" 2>/dev/null || echo "Impossible de récupérer les logs mbot"
    
    echo ""
    echo -e "${YELLOW}--- Logs nginx ---${NC}"
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
        "sudo tail -5 /var/log/nginx/access.log" 2>/dev/null || echo "Impossible de récupérer les logs nginx"
}

# Menu principal
show_menu() {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}📊 Monitoring - Chatbot MongoDB Movies${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo ""
    echo "1) 🔍 État de l'instance"
    echo "2) 📊 Métriques système"
    echo "3) 🔄 État des services"
    echo "4) 📜 Voir les logs"
    echo "5) 🔄 Tout vérifier"
    echo "6) ⏱️  Monitoring continu (30s)"
    echo "0) ❌ Quitter"
    echo ""
}

# Fonction de monitoring continu
continuous_monitoring() {
    echo -e "${BLUE}🔄 Monitoring continu (CTRL+C pour arrêter)${NC}"
    echo "=============================================="
    
    while true; do
        clear
        echo -e "${BLUE}📊 Monitoring - $(date)${NC}"
        echo "================================="
        
        check_instance_status
        if [ $? -eq 0 ]; then
            check_remote_metrics
            check_services
        fi
        
        echo ""
        echo "Prochaine vérification dans 30 secondes..."
        sleep 30
    done
}

# Configuration initiale
if [ "$INSTANCE_ID" = "i-1234567890abcdef0" ]; then
    echo -e "${RED}⚠️  CONFIGURATION REQUISE${NC}"
    echo "Veuillez modifier ce script et remplacer:"
    echo "INSTANCE_ID par votre vrai Instance ID"
    exit 1
fi

# Vérifier AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI non trouvé${NC}"
    echo "Exécutez d'abord ./setup_aws.sh"
    exit 1
fi

# Boucle du menu principal
if [ "$1" = "auto" ]; then
    # Mode automatique pour scripts
    check_instance_status
    if [ $? -eq 0 ]; then
        check_remote_metrics
        check_services
    fi
else
    # Mode interactif
    while true; do
        show_menu
        read -p "Choisissez une option: " choice
        echo ""
        
        case $choice in
            1) check_instance_status ;;
            2) 
                check_instance_status
                if [ $? -eq 0 ]; then
                    check_remote_metrics
                fi
                ;;
            3)
                check_instance_status  
                if [ $? -eq 0 ]; then
                    check_services
                fi
                ;;
            4)
                check_instance_status
                if [ $? -eq 0 ]; then
                    show_logs
                fi
                ;;
            5)
                check_instance_status
                if [ $? -eq 0 ]; then
                    check_remote_metrics
                    check_services
                    show_logs
                fi
                ;;
            6) continuous_monitoring ;;
            0) echo -e "${GREEN}👋 Monitoring terminé !${NC}"; exit 0 ;;
            *) echo -e "${RED}❌ Option invalide${NC}" ;;
        esac
        
        echo ""
        read -p "Appuyez sur Entrée pour continuer..."
        echo ""
    done
fi