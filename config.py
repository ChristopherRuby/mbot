import os
from dotenv import load_dotenv

load_dotenv()

# Configuration API Perplexity
PERPLEXITY_API_KEY = os.getenv("PERPLEXITY_API_KEY")
PERPLEXITY_API_URL = "https://api.perplexity.ai/chat/completions"
PERPLEXITY_MODEL = "sonar"  # Modèle optimisé pour la recherche avec grounding

# Configuration MongoDB
MONGODB_URI = os.getenv("MONGODB_URI")
MONGODB_DATABASE = os.getenv("MONGODB_DATABASE", "sample_mflix")
MONGODB_COLLECTION = os.getenv("MONGODB_COLLECTION", "movies")

# Configuration de l'application
APP_TITLE = "🎬 Chatbot Analytique MongoDB Movies"
APP_DESCRIPTION = """
Outil d'analyse de données cinématographiques utilisant l'intelligence artificielle pour aller analyser des données provenant de MongoDB
"""

# Métadonnées SEO
APP_KEYWORDS = "analyse données cinéma, MongoDB, business intelligence, statistiques films, outil professionnel"
APP_AUTHOR = "Data Factory - Christopher M."