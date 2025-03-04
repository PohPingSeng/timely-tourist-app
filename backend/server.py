from flask import Flask, request, jsonify
from flask_socketio import SocketIO
from recommendation_engine import RecommendationEngine
import logging

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")
engine = RecommendationEngine()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@socketio.on('connect')
def handle_connect():
    logger.info("Client connected")
    return True

@socketio.on('disconnect')
def handle_disconnect():
    logger.info("Client disconnected")
    return True

@socketio.on('get_recommendations')
def handle_recommendations(data):
    try:
        logger.info(f"Received request with data: {data}")
        
        # Add more detailed logging
        logger.info(f"Processing request for: personality_traits={data.get('personality_traits')}, "
                   f"tourism_category={data.get('tourism_category')}, "
                   f"travel_motivation={data.get('travel_motivation')}, "
                   f"travelling_concerns={data.get('travelling_concerns')}")
        
        recommendations = engine.get_recommendations(
            personality_traits=data.get('personality_traits'),
            tourism_category=data.get('tourism_category'),
            travel_motivation=data.get('travel_motivation'),
            travelling_concerns=data.get('travelling_concerns')
        )
        
        logger.info(f"Sending recommendations: {recommendations}")
        return recommendations
        
    except Exception as e:
        logger.error(f"Error processing recommendation request: {e}")
        import traceback
        logger.error(traceback.format_exc())
        return {"error": str(e), "recommendations": []}

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=9999, debug=True) 