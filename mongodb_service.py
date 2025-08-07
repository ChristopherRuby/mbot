from pymongo import MongoClient
from typing import Dict, List, Optional
import json
from bson import ObjectId
from datetime import datetime
from config import MONGODB_URI, MONGODB_DATABASE, MONGODB_COLLECTION


class MongoDBService:
    """Service pour interagir avec MongoDB Atlas - collection movies"""
    
    def __init__(self):
        self.client = None
        self.db = None
        self.collection = None
        self.connect()
    
    def _serialize_document(self, doc):
        """Convertit un document MongoDB en format JSON sérialisable"""
        if doc is None:
            return None
        
        if isinstance(doc, list):
            return [self._serialize_document(item) for item in doc]
        
        if isinstance(doc, dict):
            serialized = {}
            for key, value in doc.items():
                if isinstance(value, ObjectId):
                    serialized[key] = str(value)
                elif isinstance(value, datetime):
                    serialized[key] = value.isoformat()
                elif isinstance(value, dict):
                    serialized[key] = self._serialize_document(value)
                elif isinstance(value, list):
                    serialized[key] = self._serialize_document(value)
                else:
                    serialized[key] = value
            return serialized
        
        return doc
    
    def connect(self):
        """Établit la connexion à MongoDB Atlas"""
        try:
            self.client = MongoClient(MONGODB_URI)
            self.db = self.client[MONGODB_DATABASE]
            self.collection = self.db[MONGODB_COLLECTION]
            # Test de connexion
            self.client.admin.command('ping')
            return True
        except Exception as e:
            print(f"Erreur de connexion MongoDB: {e}")
            return False
    
    def get_sample_document(self) -> Optional[Dict]:
        """Retourne un document d'exemple pour comprendre la structure"""
        try:
            doc = self.collection.find_one()
            return self._serialize_document(doc)
        except Exception as e:
            print(f"Erreur lors de la récupération du document d'exemple: {e}")
            return None
    
    def get_collection_stats(self) -> Dict:
        """Retourne les statistiques de la collection"""
        try:
            stats = self.db.command("collStats", MONGODB_COLLECTION)
            total_docs = self.collection.count_documents({})
            return {
                "total_documents": total_docs,
                "size_mb": round(stats.get("size", 0) / (1024 * 1024), 2),
                "avg_document_size": stats.get("avgObjSize", 0),
                "indexes": len(stats.get("indexSizes", {}))
            }
        except Exception as e:
            print(f"Erreur lors de la récupération des statistiques: {e}")
            return {}
    
    def execute_query(self, query_type: str, query: Dict) -> List[Dict]:
        """
        Exécute une requête MongoDB
        
        Args:
            query_type: "find" ou "aggregate"
            query: Requête MongoDB ou pipeline d'agrégation
            
        Returns:
            Liste des résultats
        """
        if query_type == "aggregate":
            return self.execute_aggregation(query)
        else:
            return self.find_movies(query)
    
    def execute_aggregation(self, pipeline: List[Dict]) -> List[Dict]:
        """Exécute une requête d'agrégation MongoDB"""
        try:
            result = list(self.collection.aggregate(pipeline))
            return self._serialize_document(result)
        except Exception as e:
            print(f"Erreur lors de l'exécution de l'agrégation: {e}")
            return []
    
    def find_movies(self, query: Dict, limit: int = 10) -> List[Dict]:
        """Recherche des films selon des critères"""
        try:
            result = list(self.collection.find(query).limit(limit))
            return self._serialize_document(result)
        except Exception as e:
            print(f"Erreur lors de la recherche de films: {e}")
            return []
    
    def close_connection(self):
        """Ferme la connexion MongoDB"""
        if self.client:
            self.client.close()