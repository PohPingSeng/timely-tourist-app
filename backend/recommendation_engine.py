import joblib
import numpy as np
import pandas as pd
import os
from typing import List, Dict, Any

class RecommendationEngine:
    def __init__(self):
        try:
            # Ensure files exist before loading
            required_files = ["trained_model.pkl", "scaler.pkl", "model_metadata.pkl"]
            if not all(os.path.exists(f) for f in required_files):
                raise FileNotFoundError("One or more model files are missing.")

            self.model = joblib.load("trained_model.pkl")
            self.scaler = joblib.load("scaler.pkl")
            self.metadata = joblib.load("model_metadata.pkl")
            self.feature_columns = self.metadata.get('feature_columns', [])

            if not self.feature_columns:
                raise ValueError("Feature columns are missing in metadata.")
        except Exception as e:
            print(f"Error loading model files: {str(e)}")
            raise

    def _create_feature_vector(self, user_preferences: Dict[str, str]) -> np.ndarray:
        """
        Create binary feature vector from user preferences
        """
        if not self.feature_columns:
            raise ValueError("Feature columns are missing. Model metadata might be corrupted.")
        
        features = np.zeros(len(self.feature_columns))
        
        for feature in self.feature_columns:
            for key, value in user_preferences.items():
                formatted_value = f"{key}_{value}".lower().replace(" ", "_").replace(",", "").replace("&", "and")
                if feature == formatted_value:  # More precise matching
                    features[self.feature_columns.index(feature)] = 1
                    break
        
        return features.reshape(1, -1)

    def get_recommendations(self, 
                          personality_traits: str,
                          tourism_category: str,
                          travel_motivation: str = None,
                          travelling_concerns: str = None,
                          num_recommendations: int = 5) -> List[Dict[str, Any]]:
        """
        Get location recommendations based on user preferences
        """
        user_preferences = {
            "Personality Traits": personality_traits,
            "Tourism Category": tourism_category,
            "Travel Motivation": travel_motivation,
            "Travelling Concerns": travelling_concerns
        }
        
        user_preferences = {k: v for k, v in user_preferences.items() if v is not None}
        features = self._create_feature_vector(user_preferences)
        
        try:
            features_scaled = self.scaler.transform(features)
            if features_scaled.shape[1] != len(self.feature_columns):
                raise ValueError("Feature vector shape mismatch. Scaling failed.")
        except Exception as e:
            print(f"Error during feature scaling: {str(e)}")
            return []
        
        try:
            group_id = self.model.predict(features_scaled)[0]
            group_name = self.metadata.get('location_encoder', {}).inverse_transform([group_id])[0]
            locations_data = self.metadata['location_groups'].get(group_name, [])
            
            # Check if locations_data is a list of dicts or just strings
            if locations_data and isinstance(locations_data[0], dict):
                locations = locations_data
            else:
                # Convert simple location strings to dicts
                locations = [{"name": loc, "place_id": None} for loc in locations_data]
            
        except Exception as e:
            print(f"Error getting recommendations: {str(e)}")
            return []
        
        if not locations:
            print(f"No locations found for group: {group_name}")
            return []
        
        recommendations = []
        for location in locations[:num_recommendations]:
            recommendation = {
                "name": location["name"],
                "location": location["name"],
                "place_id": location["place_id"],
                "group": group_name,
                "personality_match": personality_traits,
                "category": tourism_category
            }
            if travel_motivation:
                recommendation["motivation"] = travel_motivation
            if travelling_concerns:
                recommendation["concerns"] = travelling_concerns
            
            recommendations.append(recommendation)
            print(f"Debug: Added recommendation: {recommendation}")
        
        return recommendations

    def get_similar_locations(self, location_name: str, num_recommendations: int = 5) -> List[str]:
        """
        Get similar locations to a given location
        """
        try:
            for group_name, locations in self.metadata['location_groups'].items():
                if location_name in locations:
                    similar_locations = [loc for loc in locations if loc != location_name]
                    return similar_locations[:num_recommendations]
            return []
        except Exception as e:
            print(f"Error finding similar locations: {str(e)}")
            return []

# Example usage:
if __name__ == "__main__":
    engine = RecommendationEngine()
    
    recommendations = engine.get_recommendations(
        personality_traits="Extraversion",
        tourism_category="Adrenaline Activities",
        travelling_concerns="Uniqueness & Exoticness"
    )
    
    print("\n=== Example Recommendations ===")
    for i, rec in enumerate(recommendations, 1):
        print(f"\nRecommendation {i}:")
        print(f"Location: {rec['location']}")
        print(f"Group: {rec['group']}")
        print(f"Personality Match: {rec['personality_match']}")
        print(f"Category: {rec['category']}")
        if 'motivation' in rec:
            print(f"Motivation: {rec['motivation']}")
        if 'concerns' in rec:
            print(f"Concerns: {rec['concerns']}")
    
    similar_locations = engine.get_similar_locations("Sky Deck KL Tower")
    
    print("\n=== Similar Locations ===")
    for i, location in enumerate(similar_locations, 1):
        print(f"{i}. {location}")
