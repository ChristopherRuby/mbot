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
Outil professionnel d'analyse de données cinématographiques utilisant l'intelligence artificielle.
Application web dédiée à l'exploration et l'analyse statistique de 21,349 films via requêtes en langage naturel.
Plateforme business intelligence pour professionnels du cinéma et analystes de données.
"""

# Métadonnées SEO
APP_KEYWORDS = "analyse données cinéma, MongoDB, business intelligence, statistiques films, outil professionnel"
APP_AUTHOR = "Data Factory - Christopher M."