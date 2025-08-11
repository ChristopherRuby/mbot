import streamlit as st
import json
from mongodb_service import MongoDBService
from perplexity_service import PerplexityService
from config import APP_TITLE, APP_DESCRIPTION, APP_KEYWORDS, APP_AUTHOR


def load_schema_context():
    """Charge le contexte du schéma MongoDB depuis CLAUDE.md"""
    try:
        with open("CLAUDE.md", "r", encoding="utf-8") as f:
            content = f.read()
            # Extraire la section du schéma
            start = content.find("### Schéma des Documents")
            end = content.find("## Capacités d'Analyse Supportées")
            if start != -1 and end != -1:
                return content[start:end].strip()
            return "Schéma non disponible"
    except FileNotFoundError:
        return "Fichier CLAUDE.md non trouvé"


def init_services():
    """Initialise les services MongoDB et Perplexity"""
    if 'mongodb_service' not in st.session_state:
        st.session_state.mongodb_service = MongoDBService()
    
    if 'perplexity_service' not in st.session_state:
        st.session_state.perplexity_service = PerplexityService()
    
    if 'schema_context' not in st.session_state:
        st.session_state.schema_context = load_schema_context()


def display_connection_status():
    """Affiche le statut de connexion des services"""
    col1, col2 = st.columns(2)
    
    with col1:
        if st.session_state.mongodb_service.client:
            st.success("✅ MongoDB connecté")
            stats = st.session_state.mongodb_service.get_collection_stats()
            if stats and 'total_documents' in stats:
                st.info(f"📊 {stats.get('total_documents', 0)} films dans la base")
        else:
            st.error("❌ Erreur de connexion MongoDB")
    
    with col2:
        if st.session_state.perplexity_service.api_key:
            st.success("✅ API Perplexity configurée")
        else:
            st.error("❌ Clé API Perplexity manquante")


def handle_user_question(user_question: str):
    """Traite la question de l'utilisateur"""
    
    # Étape 1: Générer la requête MongoDB via Perplexity
    with st.spinner("🧠 Analyse de votre question..."):
        query_info = st.session_state.perplexity_service.generate_mongodb_query(
            user_question, 
            st.session_state.schema_context
        )
    
    # Afficher les détails de la requête générée
    with st.expander("🔍 Détails de l'analyse"):
        st.write("**Type de requête:**", query_info.get("query_type", "inconnu"))
        st.write("**Explication:**", query_info.get("explanation", "Non disponible"))
        st.code(json.dumps(query_info.get("mongodb_query", {}), indent=2), language="json")
    
    # Étape 2: Exécuter la requête MongoDB
    if query_info.get("query_type") == "error":
        st.error(f"Erreur lors de l'analyse: {query_info.get('explanation')}")
        return
    
    with st.spinner("📊 Exécution de la requête MongoDB..."):
        try:
            mongodb_query = query_info.get("mongodb_query", {})
            query_type = query_info.get("query_type", "find")
            
            results = st.session_state.mongodb_service.execute_query(query_type, mongodb_query)
        
        except Exception as e:
            st.error(f"Erreur lors de l'exécution de la requête: {str(e)}")
            return
    
    # Étape 3: Formater la réponse via Perplexity
    with st.spinner("✨ Formatage de la réponse..."):
        formatted_response = st.session_state.perplexity_service.format_results(
            results, 
            user_question
        )
    
    # Afficher la réponse
    st.markdown("### 🎬 Réponse")
    st.markdown(formatted_response)
    
    # Afficher les données brutes si demandé
    if st.checkbox("Voir les données brutes"):
        # Détecter si l'utilisateur veut toutes les données
        needs_all_data = any(keyword in user_question.lower() for keyword in [
            "pour toutes les années", "toutes les", "chaque année", "par année", 
            "pour chaque", "détaillé", "complet", "tous les résultats"
        ])
        
        if needs_all_data or len(results) <= 10:
            st.json(results)
        else:
            st.json(results[:5])
            st.info(f"Affichage des 5 premiers résultats sur {len(results)} au total")


def main():
    """Application principale Streamlit"""
    
    st.set_page_config(
        page_title=APP_TITLE,
        page_icon="🎬",
        layout="wide",
        initial_sidebar_state="expanded",
        menu_items={
            'About': "Outil professionnel d'analyse de données cinématographiques - Data Factory"
        }
    )
    
    # Métadonnées SEO et sécurité
    st.markdown(f"""
    <meta name="description" content="{APP_DESCRIPTION.replace(chr(10), ' ').strip()}">
    <meta name="keywords" content="{APP_KEYWORDS}">
    <meta name="author" content="{APP_AUTHOR}">
    <meta name="robots" content="index, follow">
    <meta name="application-name" content="MongoDB Movies Analytics">
    <meta name="theme-color" content="#1f77b4">
    <meta property="og:title" content="{APP_TITLE}">
    <meta property="og:description" content="Plateforme professionnelle d'analyse de données cinématographiques avec IA">
    <meta property="og:type" content="website">
    <meta property="og:locale" content="fr_FR">
    """, unsafe_allow_html=True)
    
    # Headers de sécurité et information métier
    st.markdown("""
    <script>
        // Configuration sécurisée pour application business
        document.addEventListener('DOMContentLoaded', function() {
            console.log('Application Business Intelligence - Data Factory');
        });
    </script>
    """, unsafe_allow_html=True)
    
    # Signature en haut
    st.markdown("<div style='text-align: left; font-style: italic; color: #666; margin-bottom: 10px;'>By Christopher M.</div>", unsafe_allow_html=True)
    
    # Style pour bouton bleu
    st.markdown("""
    <style>
    .stButton > button[kind="primary"] {
        background-color: #1f77b4 !important;
        color: white !important;
        border: none !important;
        border-radius: 6px;
        font-weight: 500;
    }
    .stButton > button[kind="primary"]:hover {
        background-color: #1565c0 !important;
        box-shadow: 0 2px 8px rgba(31, 119, 180, 0.3);
    }
    </style>
    """, unsafe_allow_html=True)
    
    st.title(APP_TITLE)
    st.markdown(APP_DESCRIPTION)
    
    # Description professionnelle enrichie
    st.info("""
    🏢 **Application Professionnelle Business Intelligence**
    
    Plateforme d'analyse de données dédiée aux professionnels du cinéma, analystes de données et 
    chercheurs académiques. Utilise MongoDB et l'intelligence artificielle pour transformer 
    des questions en langage naturel en analyses statistiques avancées.
    
    📊 **Cas d'usage professionnel** : Études de marché, analyses de tendances, recherche académique, 
    reporting business intelligence, veille concurrentielle dans l'industrie cinématographique.
    """)
    
    # Initialiser les services
    init_services()
    
    # Afficher le statut de connexion
    display_connection_status()
    
    st.markdown("---")
    
    # Interface de chat
    st.markdown("### 💬 Posez votre question sur les films")
    
    # Exemples de questions
    st.markdown("**Exemples de questions:**")
    example_questions = [
        "Quelle est la note moyenne des films parus en 2015 ?",
        "Quels sont les 5 réalisateurs qui ont produit le plus de films entre 2000 et 2015 ?",
        "Combien de films sont sortis entre 2012 et 2014 ?",
        "Quel est le premier film paru en 2016 et qui l'a réalisé ?",
        "Peux-tu me montrer le contenu d'un document de la collection ?",
        "Quel est le genre le plus populaire par décennie entre 1970 et 2010 ?"
    ]
    
    for i, example in enumerate(example_questions):
        if st.button(f"📝 {example}", key=f"example_{i}"):
            st.session_state.user_input = example
    
    # Zone de saisie
    user_question = st.text_input(
        "Votre question:",
        key="user_input",
        placeholder="Ex: Quels sont les meilleurs films de science-fiction des années 2000 ?"
    )
    
    # Bouton d'envoi
    if st.button("🚀 Analyser", type="primary") and user_question:
        handle_user_question(user_question)
    
    # Sidebar avec informations
    with st.sidebar:
        st.markdown("### 📋 Informations")
        
        if st.button("🔄 Actualiser les stats"):
            stats = st.session_state.mongodb_service.get_collection_stats()
            if stats:
                st.metric("Films totaux", stats.get('total_documents', 0))
                st.metric("Taille (MB)", stats.get('size_mb', 0))
                st.metric("Index", stats.get('indexes', 0))
        
        st.markdown("### 🛠 Fonctionnalités Business")
        st.markdown("""
        - 📊 **Analyses statistiques** professionnelles
        - 🏆 **Classements** et études de marché
        - 🔍 **Comparaisons** multi-critères avancées
        - 📈 **Analyses croisées** et corrélations
        - 🎭 **Segmentation** par genres et périodes
        - 💼 **Reporting** business intelligence
        """)
        
        st.markdown("### 🎯 Public Cible")
        st.markdown("""
        - **Professionnels** du cinéma
        - **Analystes** de données
        - **Chercheurs** académiques
        - **Consultants** media & divertissement
        """)
        
        if st.button("📖 Voir un exemple de document"):
            sample_doc = st.session_state.mongodb_service.get_sample_document()
            if sample_doc:
                st.json(sample_doc)


if __name__ == "__main__":
    main()