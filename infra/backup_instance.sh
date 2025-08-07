#!/bin/bash
# Script de sauvegarde pour l'instance EC2 mbot

# Configuration - REMPLACEZ PAR VOS VALEURS
INSTANCE_ID="i-1234567890abcdef0"  # Votre Instance ID
BACKUP_RETENTION_DAYS=7  # Nombre de jours de rétention des snapshots

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fonction pour créer un snapshot
create_snapshot() {
    echo -e "${BLUE}💾 Création du snapshot de sauvegarde${NC}"
    echo "===================================="
    
    if [ "$INSTANCE_ID" = "i-1234567890abcdef0" ]; then
        echo -e "${RED}⚠️  Configurez d'abord INSTANCE_ID dans le script${NC}"
        return 1
    fi
    
    # Récupérer les informations de l'instance
    echo "🔍 Récupération des informations de l'instance..."
    
    VOLUME_ID=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' \
        --output text 2>/dev/null)
    
    if [ $? -ne 0 ] || [ "$VOLUME_ID" = "None" ] || [ -z "$VOLUME_ID" ]; then
        echo -e "${RED}❌ Impossible de récupérer l'ID du volume${NC}"
        return 1
    fi
    
    echo "📀 Volume ID: $VOLUME_ID"
    
    # Créer le snapshot avec timestamp
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    DESCRIPTION="mbot-backup-$TIMESTAMP"
    
    echo "📸 Création du snapshot..."
    SNAPSHOT_ID=$(aws ec2 create-snapshot \
        --volume-id $VOLUME_ID \
        --description "$DESCRIPTION" \
        --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=$DESCRIPTION},{Key=Project,Value=mbot-chatbot},{Key=CreatedBy,Value=backup_script}]" \
        --query 'SnapshotId' \
        --output text 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$SNAPSHOT_ID" ]; then
        echo -e "${GREEN}✅ Snapshot créé avec succès: $SNAPSHOT_ID${NC}"
        echo "📝 Description: $DESCRIPTION"
        
        # Attendre que le snapshot soit prêt (optionnel)
        if [ "$1" = "--wait" ]; then
            echo "⏳ Attente de la finalisation du snapshot..."
            aws ec2 wait snapshot-completed --snapshot-ids $SNAPSHOT_ID
            echo -e "${GREEN}✅ Snapshot finalisé${NC}"
        else
            echo "ℹ️  Le snapshot continue en arrière-plan"
        fi
        
        return 0
    else
        echo -e "${RED}❌ Erreur lors de la création du snapshot${NC}"
        return 1
    fi
}

# Fonction pour lister les snapshots
list_snapshots() {
    echo -e "${BLUE}📋 Liste des snapshots de sauvegarde${NC}"
    echo "===================================="
    
    SNAPSHOTS=$(aws ec2 describe-snapshots \
        --owner-ids self \
        --filters "Name=tag:Project,Values=mbot-chatbot" \
        --query 'Snapshots[*].[SnapshotId,Description,StartTime,State,Progress]' \
        --output table 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$SNAPSHOTS" ]; then
        echo "$SNAPSHOTS"
    else
        echo "❌ Aucun snapshot trouvé ou erreur"
    fi
}

# Fonction pour nettoyer les anciens snapshots
cleanup_old_snapshots() {
    echo -e "${BLUE}🧹 Nettoyage des anciens snapshots${NC}"
    echo "=================================="
    
    # Date limite (X jours en arrière)
    CUTOFF_DATE=$(date -d "$BACKUP_RETENTION_DAYS days ago" +%Y-%m-%d)
    echo "🗓️  Suppression des snapshots antérieurs au: $CUTOFF_DATE"
    
    # Récupérer les snapshots anciens
    OLD_SNAPSHOTS=$(aws ec2 describe-snapshots \
        --owner-ids self \
        --filters "Name=tag:Project,Values=mbot-chatbot" \
        --query "Snapshots[?StartTime<'$CUTOFF_DATE'].SnapshotId" \
        --output text 2>/dev/null)
    
    if [ -z "$OLD_SNAPSHOTS" ] || [ "$OLD_SNAPSHOTS" = "None" ]; then
        echo -e "${GREEN}✅ Aucun snapshot ancien à supprimer${NC}"
        return 0
    fi
    
    echo "🗑️  Snapshots à supprimer: $OLD_SNAPSHOTS"
    read -p "Confirmer la suppression ? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for snapshot_id in $OLD_SNAPSHOTS; do
            echo "🗑️  Suppression du snapshot: $snapshot_id"
            aws ec2 delete-snapshot --snapshot-id $snapshot_id
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ Snapshot $snapshot_id supprimé${NC}"
            else
                echo -e "${RED}❌ Erreur lors de la suppression de $snapshot_id${NC}"
            fi
        done
    else
        echo "❌ Suppression annulée"
    fi
}

# Fonction pour restaurer depuis un snapshot
restore_info() {
    echo -e "${BLUE}🔄 Informations sur la restauration${NC}"
    echo "===================================="
    echo ""
    echo "Pour restaurer depuis un snapshot :"
    echo ""
    echo "1. 🛑 Arrêtez l'instance actuelle :"
    echo "   ./manage_ec2.sh (option stop)"
    echo ""
    echo "2. 📀 Créez un nouveau volume depuis le snapshot :"
    echo "   aws ec2 create-volume --snapshot-id snap-xxx --availability-zone ZONE"
    echo ""
    echo "3. 🔄 Remplacez le volume de l'instance :"
    echo "   aws ec2 detach-volume --volume-id vol-old"
    echo "   aws ec2 attach-volume --volume-id vol-new --instance-id $INSTANCE_ID --device /dev/sda1"
    echo ""
    echo "4. 🚀 Redémarrez l'instance :"
    echo "   ./manage_ec2.sh (option start)"
    echo ""
    echo -e "${YELLOW}⚠️  ATTENTION: Cette opération est avancée et risquée${NC}"
    echo -e "${YELLOW}   Testez d'abord sur une copie de l'instance${NC}"
}

# Fonction d'estimation des coûts
cost_estimation() {
    echo -e "${BLUE}💰 Estimation des coûts de sauvegarde${NC}"
    echo "===================================="
    
    # Taille approximative du volume (par défaut 20GB)
    VOLUME_SIZE=20
    
    # Prix approximatif par GB/mois pour les snapshots EBS
    PRICE_PER_GB=0.05
    
    MONTHLY_COST=$(echo "scale=2; $VOLUME_SIZE * $PRICE_PER_GB * $BACKUP_RETENTION_DAYS / 30" | bc)
    
    echo "📊 Calcul basé sur :"
    echo "   - Volume: ${VOLUME_SIZE}GB"
    echo "   - Rétention: ${BACKUP_RETENTION_DAYS} jours"
    echo "   - Prix: \$${PRICE_PER_GB}/GB/mois"
    echo ""
    echo "💰 Coût estimé: ~\$${MONTHLY_COST}/mois"
    echo ""
    echo "💡 Optimisations :"
    echo "   - Snapshots incrémentiaux (seules les modifications)"
    echo "   - Suppression automatique des anciens"
    echo "   - Coût réel souvent inférieur à l'estimation"
}

# Menu principal
show_menu() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}💾 Sauvegarde - Chatbot MongoDB Movies${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
    echo "1) 💾 Créer une sauvegarde (snapshot)"
    echo "2) 📋 Lister les sauvegardes"
    echo "3) 🧹 Nettoyer les anciennes sauvegardes"
    echo "4) 🔄 Informations restauration"
    echo "5) 💰 Estimation des coûts"
    echo "6) ⚡ Sauvegarde rapide + nettoyage"
    echo "0) ❌ Quitter"
    echo ""
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

# Vérifier bc pour les calculs
if ! command -v bc &> /dev/null; then
    echo -e "${YELLOW}⚠️  'bc' non trouvé (calculs désactivés)${NC}"
fi

# Mode automatique ou interactif
if [ "$1" = "auto" ]; then
    # Mode automatique - créer sauvegarde et nettoyer
    echo -e "${BLUE}🤖 Mode automatique - Sauvegarde + Nettoyage${NC}"
    create_snapshot
    if [ $? -eq 0 ]; then
        cleanup_old_snapshots
    fi
elif [ "$1" = "create" ]; then
    # Créer seulement une sauvegarde
    create_snapshot "$2"
elif [ "$1" = "list" ]; then
    # Lister seulement
    list_snapshots
else
    # Mode interactif
    while true; do
        show_menu
        read -p "Choisissez une option: " choice
        echo ""
        
        case $choice in
            1) create_snapshot ;;
            2) list_snapshots ;;
            3) cleanup_old_snapshots ;;
            4) restore_info ;;
            5) cost_estimation ;;
            6) 
                create_snapshot
                if [ $? -eq 0 ]; then
                    cleanup_old_snapshots
                fi
                ;;
            0) echo -e "${GREEN}👋 Sauvegarde terminée !${NC}"; exit 0 ;;
            *) echo -e "${RED}❌ Option invalide${NC}" ;;
        esac
        
        echo ""
        read -p "Appuyez sur Entrée pour continuer..."
        echo ""
    done
fi