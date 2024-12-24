from flask import Flask, jsonify

app = Flask(__name__)

# Replace this with your actual HERE API Key
HERE_API_KEY = 'EQ1lKPkf5icEeKh3REYLS7acV5nRRENh4MklJlMKu9U'

@app.route('/api/config', methods=['GET'])
def get_config():
    # API endpoint to send the HERE API key
    return jsonify({'hereApiKey': HERE_API_KEY})

if __name__ == "__main__":
    app.run(debug=True)
