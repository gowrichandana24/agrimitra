import os
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report
import joblib

DATASET_DIR = os.path.join(os.path.dirname(__file__), 'dataset')
MODELS_DIR = os.path.join(os.path.dirname(__file__), 'models')
os.makedirs(MODELS_DIR, exist_ok=True)

df = pd.read_csv(os.path.join(DATASET_DIR, 'crop_recommendation_dataset.csv'))

X = df[['N', 'P', 'K', 'temperature', 'humidity', 'ph', 'rainfall']]
y = df['label']

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(X_train, y_train)

y_pred = model.predict(X_test)
accuracy = accuracy_score(y_test, y_pred)
print(f"Test accuracy: {accuracy:.2%}")
print("\nClassification report:")
print(classification_report(y_test, y_pred))

importances = pd.Series(model.feature_importances_, index=X.columns).sort_values(ascending=False)
print("\nFeature importance:")
print(importances)

model_path = os.path.join(MODELS_DIR, 'crop_rf_model.pkl')
joblib.dump(model, model_path)
print(f"\nModel saved to {model_path}")
