from recommendation_engine import RecommendationEngine

def test_recommendation_engine():
    # Initialize the engine
    engine = RecommendationEngine()
    
    # Test case 1: Nature enthusiast
    test_preferences = {
        "personality_traits": "Extraversion",
        "tourism_category": "Wild Nature Activities",
        "travelling_concerns": "Uniqueness & Exoticness"
    }
    
    print("\nTesting with preferences:", test_preferences)
    recommendations = engine.get_recommendations(
        personality_traits=test_preferences["personality_traits"],
        tourism_category=test_preferences["tourism_category"],
        travelling_concerns=test_preferences["travelling_concerns"]
    )
    
    print("\nRecommendations received:")
    for i, rec in enumerate(recommendations, 1):
        print(f"\n{i}. Location: {rec['location']}")
        print(f"   Group: {rec['group']}")
        print(f"   Category: {rec['category']}")
        print(f"   Personality Match: {rec['personality_match']}")

if __name__ == "__main__":
    test_recommendation_engine() 