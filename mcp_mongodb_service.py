import asyncio
import json
from typing import Dict, List, Any, Optional
try:
    from mcp_client import Client
    MCP_AVAILABLE = True
except ImportError:
    MCP_AVAILABLE = False
    print("MCP client non disponible, utilisation de la connexion directe MongoDB")

from mongodb_service import MongoDBService


class MCPMongoDBService:
    """
    Service hybride pour MongoDB avec support MCP ou connexion directe
    Utilise MCP si disponible, sinon fallback vers connexion directe
    """
    
    def __init__(self):
        self.use_mcp = MCP_AVAILABLE
        self.mcp_client = None
        self.mongodb_service = None
        
        if self.use_mcp:
            self._init_mcp()
        else:
            self.mongodb_service = MongoDBService()
    
    def _init_mcp(self):
        """Initialise le client MCP MongoDB"""
        try:
            # Configuration MCP MongoDB
            # À adapter selon la configuration MCP spécifique
            self.mcp_client = Client("mongodb-mcp-server")
            print("✅ MCP MongoDB client initialisé")
        except Exception as e:
            print(f"❌ Erreur MCP, fallback vers connexion directe: {e}")
            self.use_mcp = False
            self.mongodb_service = MongoDBService()
    
    async def execute_mcp_query(self, query_type: str, query: Dict) -> List[Dict]:
        """Exécute une requête via MCP"""
        if not self.use_mcp or not self.mcp_client:
            return []
        
        try:
            if query_type == "find":
                result = await self.mcp_client.call_tool(
                    "mongodb_find",
                    {
                        "collection": "movies",
                        "query": query,
                        "limit": query.get("limit", 10)
                    }
                )
            elif query_type == "aggregate":
                result = await self.mcp_client.call_tool(
                    "mongodb_aggregate", 
                    {
                        "collection": "movies",
                        "pipeline": query
                    }
                )
            else:
                return []
            
            return result.get("data", [])
            
        except Exception as e:
            print(f"Erreur MCP: {e}")
            return []
    
    def execute_query(self, query_type: str, query: Dict) -> List[Dict]:
        """
        Exécute une requête MongoDB via MCP ou connexion directe
        
        Args:
            query_type: "find" ou "aggregate"  
            query: Requête MongoDB ou pipeline d'agrégation
            
        Returns:
            Liste des résultats
        """
        if self.use_mcp:
            # Exécution asynchrone MCP
            try:
                loop = asyncio.get_event_loop()
                return loop.run_until_complete(
                    self.execute_mcp_query(query_type, query)
                )
            except Exception as e:
                print(f"Erreur lors de l'exécution MCP: {e}")
                return []
        else:
            # Fallback vers connexion directe
            if query_type == "aggregate":
                return self.mongodb_service.execute_aggregation(query)
            else:
                return self.mongodb_service.find_movies(query)
    
    def get_sample_document(self) -> Optional[Dict]:
        """Retourne un document d'exemple"""
        if self.use_mcp:
            results = self.execute_query("find", {"limit": 1})
            return results[0] if results else None
        else:
            return self.mongodb_service.get_sample_document()
    
    def get_collection_stats(self) -> Dict:
        """Retourne les statistiques de la collection"""
        if self.use_mcp:
            # Via MCP, on peut simuler les stats avec des requêtes
            try:
                total_docs = self.execute_query("aggregate", [
                    {"$count": "total"}
                ])
                total = total_docs[0]["total"] if total_docs else 0
                
                return {
                    "total_documents": total,
                    "size_mb": "N/A (MCP)",
                    "avg_document_size": "N/A (MCP)",  
                    "indexes": "N/A (MCP)"
                }
            except:
                return {"error": "Stats non disponibles via MCP"}
        else:
            return self.mongodb_service.get_collection_stats()
    
    def close_connection(self):
        """Ferme les connexions"""
        if self.mcp_client:
            # Fermeture MCP si nécessaire
            pass
        if self.mongodb_service:
            self.mongodb_service.close_connection()