import joblib
import numpy as np
import pandas as pd
from typing import List, Dict, Any

class RecommendationEngine:
    def __init__(self):
        # Load the trained model and required data
        self.model = joblib.load("trained_model.pkl")
        self.scaler = joblib.load("scaler.pkl")
        self.metadata = joblib.load("model_metadata.pkl")
        
        # Get feature columns for input processing
        self.feature_columns = self.metadata['feature_columns']
        
    def _create_feature_vector(self, user_preferences: Dict[str, str]) -> np.ndarray:
        """
        Create binary feature vector from user preferences
        """
        # Initialize feature vector with zeros
        features = np.zeros(len(self.feature_columns))
        
        # Map user preferences to binary features
        for feature in self.feature_columns:
            for key, value in user_preferences.items():
                # Convert preference to match feature name format
                formatted_value = f"{key}_{value}".lower().replace(" ", "_").replace(",", "").replace("&", "and")
                if formatted_value in feature:
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
        
        Parameters:
        - personality_traits: User's personality type
        - tourism_category: Preferred tourism category
        - travel_motivation: Travel motivation (optional)
        - travelling_concerns: Travel concerns (optional)
        - num_recommendations: Number of locations to recommend
        
        Returns:
        - List of recommended locations with details
        """
        # Create user preferences dictionary
        user_preferences = {
            "Personality Traits": personality_traits,
            "Tourism Category": tourism_category,
            "Travel Motivation": travel_motivation,
            "Travelling Concerns": travelling_concerns
        }
        
        # Remove None values
        user_preferences = {k: v for k, v in user_preferences.items() if v is not None}
        
        # Create feature vector
        features = self._create_feature_vector(user_preferences)
        
        # Scale features
        features_scaled = self.scaler.transform(features)
        
        # Get prediction
        group_id = self.model.predict(features_scaled)[0]
        
        try:
            # Get group name
            group_name = self.metadata['location_encoder'].inverse_transform([group_id])[0]
            
            # Get locations for the group
            locations = self.metadata['location_groups'].get(group_name, [])
            
            # Prepare recommendations
            recommendations = []
            for location in locations[:num_recommendations]:
                recommendation = {
                    "location": location,
                    "group": group_name,
                    "personality_match": personality_traits,
                    "category": tourism_category
                }
                if travel_motivation:
                    recommendation["motivation"] = travel_motivation
                if travelling_concerns:
                    recommendation["concerns"] = travelling_concerns
                    
                recommendations.append(recommendation)
            
            return recommendations
            
        except Exception as e:
            print(f"Error getting recommendations: {str(e)}")
            return []

    def get_similar_locations(self, location_name: str, num_recommendations: int = 5) -> List[str]:
        """
        Get similar locations to a given location
        """
        try:
            # Find the group containing this location
            for group_name, locations in self.metadata['location_groups'].items():
                if location_name in locations:
                    # Return other locations from the same group
                    similar_locations = [loc for loc in locations if loc != location_name]
                    return similar_locations[:num_recommendations]
            
            return []
            
        except Exception as e:
            print(f"Error finding similar locations: {str(e)}")
            return []

# Example usage:
if __name__ == "__main__":
    # Initialize recommendation engine
    engine = RecommendationEngine()
    
    # Example 1: Get recommendations based on preferences
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
    
    # Example 2: Get similar locations
    similar_locations = engine.get_similar_locations("Sky Deck KL Tower")
    
    print("\n=== Similar Locations ===")
    for i, location in enumerate(similar_locations, 1):
        print(f"{i}. {location}") 