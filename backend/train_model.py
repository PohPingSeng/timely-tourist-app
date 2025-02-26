import joblib
import numpy as np
import pandas as pd
from sklearn.neural_network import MLPClassifier
from sklearn.metrics import accuracy_score, classification_report
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import confusion_matrix
from sklearn.utils.class_weight import compute_class_weight

# Load data and metadata
X_train, X_test, y_train, y_test = joblib.load("processed_data.pkl")
metadata = joblib.load("model_metadata.pkl")

# Convert to numpy arrays if they're pandas objects
X_train = np.asarray(X_train)
X_test = np.asarray(X_test)
y_train = np.asarray(y_train)
y_test = np.asarray(y_test)

# Scale features
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# Create Neural Network with improved architecture
print("\n🧠 Training Neural Network Model...")
nn_model = MLPClassifier(
    hidden_layer_sizes=(512, 256, 128, 64),
    activation='relu',
    solver='adam',
    alpha=0.0001,  # L2 regularization
    batch_size=16,  # Smaller batch size for better generalization
    learning_rate='adaptive',
    learning_rate_init=0.001,
    max_iter=2000,
    early_stopping=True,
    validation_fraction=0.15,
    n_iter_no_change=25,  # Increased patience
    random_state=42,
    verbose=True,
    shuffle=True,
    tol=1e-5  # Reduced tolerance for better convergence
)

# Train the model
nn_model.fit(X_train_scaled, y_train)

# Make predictions
y_train_pred = nn_model.predict(X_train_scaled)
y_test_pred = nn_model.predict(X_test_scaled)

# Calculate metrics
print("\n=== Neural Network Performance ===")
print(f"Training Accuracy: {accuracy_score(y_train, y_train_pred):.4f}")
print(f"Testing Accuracy: {accuracy_score(y_test, y_test_pred):.4f}")

# Print detailed classification report
print("\n=== Detailed Classification Report ===")
print(classification_report(y_test, y_test_pred))

# Save the model and scaler
joblib.dump(nn_model, "trained_model.pkl")
joblib.dump(scaler, "scaler.pkl")

print("\n📁 Model and scaler saved successfully")

# Function to get recommended locations
def get_recommendations(group_id, metadata, top_k=5):
    """Get location recommendations for a group"""
    try:
        group_name = metadata['location_encoder'].inverse_transform([group_id])[0]
        locations = metadata['location_groups'].get(group_name, [])
        return locations[:top_k]
    except:
        return []

# Print example predictions with recommendations
print("\n=== Example Predictions ===")
test_indices = np.arange(len(y_test))
np.random.shuffle(test_indices)
for i in test_indices[:5]:  # Show 5 random examples
    pred_group = y_test_pred[i]
    true_group = y_test[i]
    
    try:
        pred_group_name = metadata['location_encoder'].inverse_transform([pred_group])[0]
        true_group_name = metadata['location_encoder'].inverse_transform([true_group])[0]
        
        print(f"\nPrediction {i+1}:")
        print(f"Predicted group: {pred_group_name}")
        print(f"True group: {true_group_name}")
        
        recommended_locations = get_recommendations(pred_group, metadata)
        if recommended_locations:
            print("Recommended locations:")
            for loc in recommended_locations:
                print(f"- {loc}")
    except Exception as e:
        print(f"Error processing prediction {i}: {str(e)}")

# Print final model performance
print("\n=== Final Model Summary ===")
print(f"Model type: Neural Network")
print(f"Architecture: {nn_model.hidden_layer_sizes}")
print(f"Training accuracy: {accuracy_score(y_train, y_train_pred):.4f}")
print(f"Testing accuracy: {accuracy_score(y_test, y_test_pred):.4f}")
print(f"Number of iterations: {nn_model.n_iter_}")
print(f"Best validation score: {nn_model.best_validation_score_:.4f}")

# Print group prediction distribution
print("\n=== Prediction Distribution ===")
pred_counts = pd.Series(y_test_pred).value_counts()
print(f"Number of unique groups predicted: {len(pred_counts)}")
print(f"Average predictions per group: {pred_counts.mean():.2f}")
print(f"Min predictions per group: {pred_counts.min()}")
print(f"Max predictions per group: {pred_counts.max()}")

# Print some example groups
print("\n=== Example Groups and Their Locations ===")
unique_groups = np.unique(y_test)
np.random.shuffle(unique_groups)
for group in unique_groups[:3]:  # Show 3 random groups
    try:
        group_name = metadata['location_encoder'].inverse_transform([group])[0]
        locations = metadata['location_groups'].get(group_name, [])
        print(f"\nGroup: {group_name}")
        print("Locations:")
        for loc in locations[:3]:  # Show first 3 locations
            print(f"- {loc}")
    except Exception as e:
        print(f"Error processing group {group}: {str(e)}")
