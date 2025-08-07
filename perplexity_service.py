import requests
import json
from typing import Dict, List
from config import PERPLEXITY_API_KEY, PERPLEXITY_API_URL, PERPLEXITY_MODEL


class PerplexityService:
    """Service pour interagir avec l'API Perplexity"""
    
    def __init__(self):
        self.api_key = PERPLEXITY_API_KEY
        self.api_url = PERPLEXITY_API_URL
        self.model = PERPLEXITY_MODEL
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
    
    def _get_standard_query(self, user_question: str) -> Dict:
        """Retourne une requête standard pour les questions courantes"""
        question_lower = user_question.lower()
        
        # Questions pour voir un document d'exemple (SANS critères spécifiques)
        has_document_keywords = any(keyword in question_lower for keyword in [
            "document", "exemple", "contenu d'un document", "structure", 
            "voir un document", "montrer un document", "échantillon"
        ])
        
        # Vérifier s'il y a des critères spécifiques (années, genres, etc.)
        has_specific_criteria = any(criteria in question_lower for criteria in [
            "en 20", "année", "genre", "réalisateur", "acteur", "note", 
            "paru en", "sorti en", "de 19", "de 20", "entre", "avec",
            "rating", "imdb", "director", "cast", "spielberg", "scorsese",
            "supérieure", "inférieure", "action", "drame", "comédie",
            "thriller", "horreur", "romance", "animation"
        ])
        
        # Seulement si document demandé SANS critères spécifiques
        if has_document_keywords and not has_specific_criteria:
            return {
                "query_type": "find",
                "mongodb_query": {},
                "explanation": "Récupération d'un document d'exemple de la collection movies",
                "estimated_results": "Un document complet avec tous les champs disponibles"
            }
        
        # Questions pour le total de films
        if any(keyword in question_lower for keyword in [
            "combien de films au total", "nombre total de films", "total de films",
            "combien de films dans la collection", "taille de la collection"
        ]):
            return {
                "query_type": "aggregate",
                "mongodb_query": [{"$count": "total"}],
                "explanation": "Comptage du nombre total de films dans la collection",
                "estimated_results": "Le nombre total de documents"
            }
        
        return None
    
    def generate_mongodb_query(self, user_question: str, schema_context: str) -> Dict:
        """
        Génère une requête MongoDB à partir d'une question en langage naturel
        
        Args:
            user_question: Question de l'utilisateur
            schema_context: Contexte du schéma MongoDB
            
        Returns:
            Dict contenant la requête MongoDB et l'explication
        """
        
        # Vérifier d'abord les questions standards
        standard_query = self._get_standard_query(user_question)
        if standard_query:
            return standard_query
        
        system_prompt = f"""Tu es un expert en MongoDB et en analyse de données cinématographiques. 

Ton rôle est de convertir des questions en langage naturel en requêtes MongoDB pour la collection 'movies'.

SCHÉMA DE LA COLLECTION MOVIES:
{schema_context}

RÈGLES IMPORTANTES:
- Pour les années, utilise le champ 'year' (nombre)
- Pour les intervalles d'années: {{"year": {{"$gte": 2012, "$lte": 2014}}}}
- Pour compter: utilise une requête aggregate avec $match et $count
- Pour les top N: utilise $sort et $limit dans un pipeline d'agrégation
- Pour les moyennes: utilise $group avec $avg

EXEMPLES DE REQUÊTES STANDARDS:
- Montrer un document: {{"query_type": "find", "mongodb_query": {{}}, "explanation": "Récupération d'un document d'exemple", "estimated_results": "Un document"}}
- Compter films entre 2012-2014: [{{"$match": {{"year": {{"$gte": 2012, "$lte": 2014}}}}}}, {{"$count": "total"}}]
- Top réalisateurs: [{{"$unwind": "$directors"}}, {{"$group": {{"_id": "$directors", "count": {{"$sum": 1}}}}}}, {{"$sort": {{"count": -1}}}}, {{"$limit": 5}}]
- Notes moyennes par année: [{{"$match": {{"year": {{"$gte": 2005, "$lte": 2010}}, "imdb.rating": {{"$exists": true}}}}}}, {{"$group": {{"_id": "$year", "avgRating": {{"$avg": "$imdb.rating"}}}}}}, {{"$sort": {{"_id": 1}}}}]

QUESTIONS STANDARDS ET LEURS REQUÊTES:
- "document", "exemple", "contenu d'un document" → find vide {{}}
- "combien", "nombre" → aggregate avec $count
- "moyenne", "note moyenne" → aggregate avec $avg
- "top", "meilleurs", "classement" → aggregate avec $sort + $limit

RÉPONSE REQUISE - JSON valide uniquement:
{{
    "query_type": "find|aggregate",
    "mongodb_query": {{...}} ou [...],
    "explanation": "explication concise",
    "estimated_results": "type de résultats"
}}

Question: {user_question}"""

        try:
            payload = {
                "model": self.model,
                "messages": [
                    {
                        "role": "system",
                        "content": system_prompt
                    },
                    {
                        "role": "user", 
                        "content": user_question
                    }
                ],
                "max_tokens": 1000,
                "temperature": 0.0,  # Température très basse pour plus de consistance
                "stream": False
            }
            
            response = requests.post(self.api_url, headers=self.headers, json=payload)
            response.raise_for_status()
            
            result = response.json()
            content = result["choices"][0]["message"]["content"]
            
            # Tenter de parser le JSON de la réponse
            try:
                # Nettoyer le contenu si nécessaire
                content = content.strip()
                if content.startswith("```json"):
                    content = content.replace("```json", "").replace("```", "").strip()
                elif content.startswith("```"):
                    content = content.replace("```", "").strip()
                
                return json.loads(content)
            except json.JSONDecodeError as e:
                print(f"Erreur de parsing JSON: {e}")
                print(f"Contenu reçu: {content}")
                # Si ce n'est pas du JSON valide, retourner une structure par défaut
                return {
                    "query_type": "error",
                    "mongodb_query": {},
                    "explanation": f"Erreur de parsing JSON de l'API Perplexity. Contenu reçu: {content[:200]}...",
                    "estimated_results": "Aucun"
                }
                
        except Exception as e:
            return {
                "query_type": "error",
                "mongodb_query": {},
                "explanation": f"Erreur API Perplexity: {str(e)}",
                "estimated_results": "Aucun"
            }
    
    def format_results(self, query_results: List[Dict], user_question: str) -> str:
        """
        Formate les résultats de la requête MongoDB en réponse naturelle
        
        Args:
            query_results: Résultats de la requête MongoDB
            user_question: Question originale de l'utilisateur
            
        Returns:
            Réponse formatée en langage naturel
        """
        
        if not query_results:
            return "Aucun résultat trouvé pour votre question."
        
        results_summary = f"Nombre de résultats: {len(query_results)}\n\n"
        
        # Détecter les questions nécessitant tous les résultats
        needs_complete_results = any(keyword in user_question.lower() for keyword in [
            "pour toutes les années", "toutes les", "chaque année", "par année", 
            "pour chaque", "détaillé", "complet", "tous les résultats"
        ])
        
        if len(query_results) <= 10 or needs_complete_results:
            results_summary += "Résultats complets:\n" + json.dumps(query_results, indent=2, ensure_ascii=False)
        else:
            results_summary += "Aperçu des premiers résultats:\n" + json.dumps(query_results[:5], indent=2, ensure_ascii=False)
            results_summary += f"\n\n... et {len(query_results)-5} autres résultats."
        
        # Instructions adaptées selon le type de question
        complete_instruction = ""
        if needs_complete_results:
            complete_instruction = "\n\nIMPORTANT: L'utilisateur demande TOUTES les données. Tu DOIS présenter CHAQUE résultat fourni dans les données, sans exception. Ne pas omettre ou résumer aucune donnée."
        
        format_prompt = f"""Voici les résultats d'une requête MongoDB pour la question: "{user_question}"

DONNÉES:
{results_summary}

Formate cette réponse de manière claire et professionnelle en:
1. Répondant directement à la question
2. Présentant TOUTES les données importantes de façon structurée (tableaux, listes)
3. Ajoutant du contexte analytique pertinent
4. Proposant des analyses complémentaires si approprié{complete_instruction}

Réponse naturelle et accessible:"""

        try:
            payload = {
                "model": self.model,
                "messages": [
                    {
                        "role": "user",
                        "content": format_prompt
                    }
                ],
                "max_tokens": 2500 if needs_complete_results else 1500,
                "temperature": 0.3,
                "stream": False
            }
            
            response = requests.post(self.api_url, headers=self.headers, json=payload)
            response.raise_for_status()
            
            result = response.json()
            return result["choices"][0]["message"]["content"]
            
        except Exception as e:
            return f"Erreur lors du formatage: {str(e)}\n\nRésultats bruts:\n{results_summary}"