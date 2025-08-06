#!/usr/bin/env python3
"""
Script de test pour vérifier le bon fonctionnement du chatbot MongoDB Movies
"""

import os
import sys
from dotenv import load_dotenv

# Charger les variables d'environnement
load_dotenv()

def test_environment():
    """Test la configuration de l'environnement"""
    print("🔍 Test de la configuration...")
    
    required_vars = ["PERPLEXITY_API_KEY", "MONGODB_URI"]
    missing_vars = []
    
    for var in required_vars:
        if not os.getenv(var):
            missing_vars.append(var)
    
    if missing_vars:
        print(f"❌ Variables d'environnement manquantes: {', '.join(missing_vars)}")
        return False
    else:
        print("✅ Configuration d'environnement OK")
        return True

def test_imports():
    """Test les imports des modules"""
    print("\n📦 Test des imports...")
    
    try:
        import streamlit
        print("✅ Streamlit importé")
        
        import requests  
        print("✅ Requests importé")
        
        import pymongo
        print("✅ PyMongo importé")
        
        from mongodb_service import MongoDBService
        print("✅ MongoDBService importé")
        
        from perplexity_service import PerplexityService
        print("✅ PerplexityService importé")
        
        return True
        
    except ImportError as e:
        print(f"❌ Erreur d'import: {e}")
        return False

def test_mongodb_connection():
    """Test la connexion MongoDB"""
    print("\n🗄️ Test de la connexion MongoDB...")
    
    try:
        from mongodb_service import MongoDBService
        
        mongo_service = MongoDBService()
        
        if mongo_service.client:
            print("✅ Connexion MongoDB établie")
            
            # Test des statistiques
            stats = mongo_service.get_collection_stats()
            if stats:
                print(f"📊 {stats.get('total_documents', 0)} documents dans la collection")
                
            # Test document d'exemple
            sample = mongo_service.get_sample_document()
            if sample:
                print("✅ Document d'exemple récupéré")
            
            mongo_service.close_connection()
            return True
        else:
            print("❌ Échec de la connexion MongoDB")
            return False
            
    except Exception as e:
        print(f"❌ Erreur MongoDB: {e}")
        return False

def test_perplexity_api():
    """Test l'API Perplexity (sans faire de requête réelle)"""
    print("\n🤖 Test de la configuration Perplexity...")
    
    try:
        from perplexity_service import PerplexityService
        
        perplexity_service = PerplexityService()
        
        if perplexity_service.api_key:
            print("✅ Clé API Perplexity configurée")
            print(f"🔧 Modèle utilisé: {perplexity_service.model}")
            return True
        else:
            print("❌ Clé API Perplexity manquante")
            return False
            
    except Exception as e:
        print(f"❌ Erreur configuration Perplexity: {e}")
        return False

def test_schema_loading():
    """Test le chargement du schéma depuis CLAUDE.md"""
    print("\n📋 Test du chargement du schéma...")
    
    try:
        with open("CLAUDE.md", "r", encoding="utf-8") as f:
            content = f.read()
            
        if "### Schéma des Documents" in content:
            print("✅ Schéma MongoDB trouvé dans CLAUDE.md")
            return True
        else:
            print("⚠️ Section schéma non trouvée dans CLAUDE.md")
            return False
            
    except FileNotFoundError:
        print("❌ Fichier CLAUDE.md non trouvé")
        return False
    except Exception as e:
        print(f"❌ Erreur lecture CLAUDE.md: {e}")
        return False

def main():
    """Fonction principale de test"""
    print("🎬 Test du Chatbot Analytique MongoDB Movies")
    print("=" * 50)
    
    tests = [
        test_environment,
        test_imports,
        test_schema_loading,
        test_perplexity_api,
        test_mongodb_connection
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        if test():
            passed += 1
    
    print("\n" + "=" * 50)
    print(f"📊 Résultats: {passed}/{total} tests réussis")
    
    if passed == total:
        print("🎉 Tous les tests sont passés ! L'application est prête.")
        print("\n🚀 Pour lancer l'application:")
        print("   streamlit run app.py")
    else:
        print("⚠️ Certains tests ont échoué. Vérifiez la configuration.")
        
    return passed == total

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)