#!/bin/bash
# Script de gestion Elastic IP pour l'instance EC2 mbot

# Configuration - REMPLACEZ PAR VOS VALEURS  
INSTANCE_ID="i-1234567890abcdef0"  # Votre Instance ID

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fonction pour allouer une nouvelle Elastic IP
allocate_elastic_ip() {
    echo -e "${BLUE}🌐 Allocation d'une nouvelle Elastic IP${NC}"
    echo "===================================="
    
    echo "💰 Coût: ~$3.60/mois si attachée à une instance"
    echo "💡 Gratuit si l'instance est en cours d'exécution"
    echo ""
    read -p "Confirmer l'allocation ? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Allocation annulée"
        return 1
    fi
    
    # Allouer l'Elastic IP
    echo "🔄 Allocation en cours..."
    ALLOCATION_OUTPUT=$(aws ec2 allocate-address --domain vpc --output json 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        ALLOCATION_ID=$(echo $ALLOCATION_OUTPUT | jq -r '.AllocationId')
        PUBLIC_IP=$(echo $ALLOCATION_OUTPUT | jq -r '.PublicIp')
        
        echo -e "${GREEN}✅ Elastic IP allouée avec succès${NC}"
        echo "🆔 Allocation ID: $ALLOCATION_ID"
        echo "🌐 IP Publique: $PUBLIC_IP"
        
        # Sauvegarder dans un fichier local
        echo "{\"allocation_id\": \"$ALLOCATION_ID\", \"public_ip\": \"$PUBLIC_IP\", \"created_at\": \"$(date -Iseconds)\"}" > elastic_ip.json
        echo "💾 Informations sauvegardées dans elastic_ip.json"
        
        return 0
    else
        echo -e "${RED}❌ Erreur lors de l'allocation${NC}"
        return 1
    fi
}

# Fonction pour associer l'Elastic IP à l'instance
associate_elastic_ip() {
    echo -e "${BLUE}🔗 Association de l'Elastic IP à l'instance${NC}"
    echo "============================================="
    
    if [ "$INSTANCE_ID" = "i-1234567890abcdef0" ]; then
        echo -e "${RED}⚠️  Configurez d'abord INSTANCE_ID dans le script${NC}"
        return 1
    fi
    
    # Vérifier si un fichier elastic_ip.json existe
    if [ -f "elastic_ip.json" ]; then
        ALLOCATION_ID=$(jq -r '.allocation_id' elastic_ip.json 2>/dev/null)
        PUBLIC_IP=$(jq -r '.public_ip' elastic_ip.json 2>/dev/null)
        
        if [ "$ALLOCATION_ID" != "null" ] && [ -n "$ALLOCATION_ID" ]; then
            echo "📁 Utilisation de l'Elastic IP du fichier: $PUBLIC_IP"
        else
            echo "❌ Fichier elastic_ip.json invalide"
            return 1
        fi
    else
        # Demander l'Allocation ID
        echo "Entrez l'Allocation ID de votre Elastic IP:"
        read -p "Allocation ID (eipalloc-xxx): " ALLOCATION_ID
        
        if [ -z "$ALLOCATION_ID" ]; then
            echo "❌ Allocation ID requis"
            return 1
        fi
    fi
    
    # Vérifier que l'instance est en cours d'exécution
    INSTANCE_STATE=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text 2>/dev/null)
    
    if [ "$INSTANCE_STATE" != "running" ]; then
        echo -e "${RED}❌ L'instance doit être en cours d'exécution${NC}"
        echo "État actuel: $INSTANCE_STATE"
        return 1
    fi
    
    # Associer l'IP
    echo "🔄 Association en cours..."
    ASSOCIATION_ID=$(aws ec2 associate-address \
        --instance-id $INSTANCE_ID \
        --allocation-id $ALLOCATION_ID \
        --query 'AssociationId' \
        --output text 2>/dev/null)
    
    if [ $? -eq 0 ] && [ "$ASSOCIATION_ID" != "None" ]; then
        echo -e "${GREEN}✅ Elastic IP associée avec succès${NC}"
        echo "🆔 Association ID: $ASSOCIATION_ID"
        echo "🌐 Votre application est maintenant accessible sur: http://$PUBLIC_IP"
        
        # Mettre à jour le fichier local
        if [ -f "elastic_ip.json" ]; then
            TEMP_FILE=$(mktemp)
            jq ". + {\"association_id\": \"$ASSOCIATION_ID\", \"instance_id\": \"$INSTANCE_ID\", \"associated_at\": \"$(date -Iseconds)\"}" elastic_ip.json > $TEMP_FILE && mv $TEMP_FILE elastic_ip.json
        fi
        
        return 0
    else
        echo -e "${RED}❌ Erreur lors de l'association${NC}"
        return 1
    fi
}

# Fonction pour dissocier l'Elastic IP
disassociate_elastic_ip() {
    echo -e "${BLUE}🔌 Dissociation de l'Elastic IP${NC}"
    echo "==============================="
    
    if [ -f "elastic_ip.json" ]; then
        ASSOCIATION_ID=$(jq -r '.association_id // empty' elastic_ip.json 2>/dev/null)
    fi
    
    if [ -z "$ASSOCIATION_ID" ] || [ "$ASSOCIATION_ID" = "null" ]; then
        echo "Entrez l'Association ID:"
        read -p "Association ID (eipassoc-xxx): " ASSOCIATION_ID
        
        if [ -z "$ASSOCIATION_ID" ]; then
            echo "❌ Association ID requis"
            return 1
        fi
    fi
    
    echo "🔄 Dissociation en cours..."
    aws ec2 disassociate-address --association-id $ASSOCIATION_ID
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Elastic IP dissociée avec succès${NC}"
        echo -e "${YELLOW}⚠️  L'instance aura une nouvelle IP au prochain démarrage${NC}"
        
        # Mettre à jour le fichier local
        if [ -f "elastic_ip.json" ]; then
            TEMP_FILE=$(mktemp)
            jq ". + {\"association_id\": null, \"disassociated_at\": \"$(date -Iseconds)\"}" elastic_ip.json > $TEMP_FILE && mv $TEMP_FILE elastic_ip.json
        fi
        
        return 0
    else
        echo -e "${RED}❌ Erreur lors de la dissociation${NC}"
        return 1
    fi
}

# Fonction pour libérer l'Elastic IP
release_elastic_ip() {
    echo -e "${BLUE}🗑️  Libération de l'Elastic IP${NC}"
    echo "=============================="
    
    if [ -f "elastic_ip.json" ]; then
        ALLOCATION_ID=$(jq -r '.allocation_id' elastic_ip.json 2>/dev/null)
        PUBLIC_IP=$(jq -r '.public_ip' elastic_ip.json 2>/dev/null)
        
        if [ "$ALLOCATION_ID" != "null" ] && [ -n "$ALLOCATION_ID" ]; then
            echo "📁 IP à libérer: $PUBLIC_IP ($ALLOCATION_ID)"
        else
            echo "❌ Fichier elastic_ip.json invalide"
            return 1
        fi
    else
        echo "Entrez l'Allocation ID de l'Elastic IP à libérer:"
        read -p "Allocation ID (eipalloc-xxx): " ALLOCATION_ID
        
        if [ -z "$ALLOCATION_ID" ]; then
            echo "❌ Allocation ID requis"
            return 1
        fi
    fi
    
    echo -e "${RED}⚠️  ATTENTION: Cette action est irréversible${NC}"
    echo "💰 Vous ne serez plus facturé pour cette IP"
    echo "🔄 L'IP sera attribuée à un autre utilisateur AWS"
    echo ""
    read -p "Confirmer la libération ? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Libération annulée"
        return 1
    fi
    
    # Libérer l'IP
    echo "🔄 Libération en cours..."
    aws ec2 release-address --allocation-id $ALLOCATION_ID
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Elastic IP libérée avec succès${NC}"
        
        # Supprimer le fichier local
        if [ -f "elastic_ip.json" ]; then
            rm elastic_ip.json
            echo "🗑️  Fichier local supprimé"
        fi
        
        return 0
    else
        echo -e "${RED}❌ Erreur lors de la libération${NC}"
        return 1
    fi
}

# Fonction pour lister les Elastic IP
list_elastic_ips() {
    echo -e "${BLUE}📋 Liste de vos Elastic IP${NC}"
    echo "=========================="
    
    EIP_LIST=$(aws ec2 describe-addresses --output table 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "$EIP_LIST"
    else
        echo "❌ Erreur lors de la récupération des Elastic IP"
    fi
    
    # Afficher les informations du fichier local si disponible
    if [ -f "elastic_ip.json" ]; then
        echo ""
        echo -e "${BLUE}📁 Informations locales:${NC}"
        cat elastic_ip.json | jq . 2>/dev/null || echo "Fichier local invalide"
    fi
}

# Menu principal
show_menu() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}🌐 Elastic IP - Chatbot MongoDB Movies${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "1) 🌐 Allouer une nouvelle Elastic IP"
    echo "2) 🔗 Associer à l'instance"
    echo "3) 🔌 Dissocier de l'instance"
    echo "4) 🗑️  Libérer une Elastic IP"
    echo "5) 📋 Lister toutes les Elastic IP"
    echo "6) 💰 Information sur les coûts"
    echo "0) ❌ Quitter"
    echo ""
}

# Information sur les coûts
cost_info() {
    echo -e "${BLUE}💰 Informations sur les coûts Elastic IP${NC}"
    echo "========================================="
    echo ""
    echo "📊 Tarification AWS Elastic IP :"
    echo ""
    echo "✅ GRATUIT si :"
    echo "   - Attachée à une instance EN COURS D'EXÉCUTION"
    echo "   - Une seule IP par instance"
    echo ""
    echo "💰 PAYANT (~$3.60/mois) si :"
    echo "   - Attachée à une instance ARRÊTÉE"
    echo "   - Non attachée (IP réservée)"
    echo "   - IP supplémentaires sur la même instance"
    echo ""
    echo "💡 Bonnes pratiques :"
    echo "   - Libérez les IP non utilisées"
    echo "   - Une IP par instance maximum"
    echo "   - Associez/dissociez selon l'état de l'instance"
    echo ""
    echo "🔄 Workflow économique :"
    echo "   - Instance ON: Associer l'IP"
    echo "   - Instance OFF: Dissocier l'IP (ou garder si usage régulier)"
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

# Vérifier jq
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  'jq' non trouvé (fonctionnalités limitées)${NC}"
    echo "Installation recommandée: sudo apt install jq"
fi

# Mode interactif
while true; do
    show_menu
    read -p "Choisissez une option: " choice
    echo ""
    
    case $choice in
        1) allocate_elastic_ip ;;
        2) associate_elastic_ip ;;
        3) disassociate_elastic_ip ;;
        4) release_elastic_ip ;;
        5) list_elastic_ips ;;
        6) cost_info ;;
        0) echo -e "${GREEN}👋 Gestion Elastic IP terminée !${NC}"; exit 0 ;;
        *) echo -e "${RED}❌ Option invalide${NC}" ;;
    esac
    
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
    echo ""
done