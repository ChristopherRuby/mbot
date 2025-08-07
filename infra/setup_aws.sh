#!/bin/bash
# Configuration initiale AWS CLI pour le projet mbot

set -e

echo "🔧 Configuration AWS CLI pour le Chatbot MongoDB Movies"
echo "====================================================="

# Vérifier si AWS CLI est installé
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI non trouvé. Installation en cours..."
    
    # Installation AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
    
    echo "✅ AWS CLI installé"
fi

# Configuration AWS CLI
echo ""
echo "🔑 Configuration des credentials AWS..."
echo "Vous aurez besoin de :"
echo "- Access Key ID"
echo "- Secret Access Key"
echo "- Région (ex: eu-west-1, us-east-1)"
echo ""

# Lancer la configuration interactive
aws configure

echo ""
echo "🧪 Test de la configuration..."

# Test basique
if aws sts get-caller-identity &>/dev/null; then
    echo "✅ Credentials AWS valides"
    
    # Afficher les informations du compte
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    REGION=$(aws configure get region)
    
    echo ""
    echo "📊 Informations du compte AWS :"
    echo "Account ID: $ACCOUNT_ID"
    echo "User/Role: $USER_ARN"
    echo "Région: $REGION"
    
else
    echo "❌ Erreur de configuration AWS"
    echo "Vérifiez vos credentials et réessayez"
    exit 1
fi

echo ""
echo "🔍 Vérification des permissions EC2..."

# Test des permissions EC2
if aws ec2 describe-instances --max-items 1 &>/dev/null; then
    echo "✅ Permissions EC2 OK"
else
    echo "⚠️  Permissions EC2 limitées"
    echo "Assurez-vous d'avoir les permissions EC2 nécessaires"
fi

echo ""
echo "📝 Création du fichier de configuration du projet..."

# Créer un fichier de config local
cat > ../aws-config.json << EOF
{
    "account_id": "$ACCOUNT_ID",
    "region": "$REGION",
    "project_name": "mbot-chatbot",
    "instance_type": "t3.small",
    "created_at": "$(date -Iseconds)"
}
EOF

echo "✅ Configuration sauvegardée dans aws-config.json"

echo ""
echo "🎉 Configuration AWS terminée avec succès !"
echo ""
echo "Prochaines étapes :"
echo "1. Créez votre instance EC2 via la console AWS"
echo "2. Notez l'Instance ID"
echo "3. Modifiez manage_ec2.sh avec votre Instance ID"
echo "4. Exécutez ./deploy_ec2.sh sur votre instance"