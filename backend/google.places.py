import requests
import json

# Replace this with your actual Google Maps API key
API_KEY = 'AIzaSyCQMJ0APEwgYCKAKfuwco09cLD3mc-HS-A'

# Function to get attractions from Google Places API
def get_attractions(location, type_of_attraction="tourist_attractions"):
    """
    Fetches nearby attractions based on the location using Google Places API.
    
    Parameters:
        location (str): The location (latitude, longitude) or place name.
        type_of_attraction (str): Type of attraction to search for (default is tourist attractions).
    
    Returns:
        dict: A dictionary containing attraction data or an error message.
    """
    
    # Google Places API endpoint for places search
    endpoint = "https://maps.googleapis.com/maps/api/place/textsearch/json"
    
    # Form the search query to find tourist attractions
    query = f"{location} {type_of_attraction}"
    
    # Send the GET request to Google Places API
    response = requests.get(endpoint, params={
        'query': query,
        'key': API_KEY
    })
    
    # If the request is successful
    if response.status_code == 200:
        results = response.json().get('results', [])
        
        # Create a list to store attraction details
        attractions = []
        
        for place in results:
            attraction = {
                'name': place.get('name'),
                'address': place.get('formatted_address'),
                'rating': place.get('rating', 'No rating available'),
                'photo_reference': place.get('photos', [{}])[0].get('photo_reference'),
                'latitude': place.get('geometry', {}).get('location', {}).get('lat'),
                'longitude': place.get('geometry', {}).get('location', {}).get('lng')
            }
            attractions.append(attraction)
        
        return attractions
    
    else:
        # Handle errors (API quota exceeded, invalid request, etc.)
        return {'error': f"Error fetching data: {response.status_code}"}

# Example usage
if __name__ == "__main__":
    location = "Paris, France"
    attractions = get_attractions(location)
    print(json.dumps(attractions, indent=2))
