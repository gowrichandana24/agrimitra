"""
Crop Image Recognition Model Training
Uses MobileNetV2 transfer learning for lightweight crop/fruit/vegetable classification.
"""

import os
import json
import tensorflow as tf
from tensorflow.keras import layers, models
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.applications.mobilenet_v2 import preprocess_input
from sklearn.metrics import classification_report
import numpy as np

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATASET_DIR = os.path.join(BASE_DIR, 'dataset', 'crop_image_recognition')
MODELS_DIR = os.path.join(BASE_DIR, 'models')

TRAIN_DIR = os.path.join(DATASET_DIR, 'train')
VAL_DIR = os.path.join(DATASET_DIR, 'validation')
TEST_DIR = os.path.join(DATASET_DIR, 'test')

IMG_SIZE = 224
BATCH_SIZE = 32
EPOCHS = 8
NUM_CLASSES = 36


def load_datasets():
    """Load train, validation, and test datasets using ImageFolder-style directory."""
    train_ds = tf.keras.utils.image_dataset_from_directory(
        TRAIN_DIR,
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        label_mode='int',
        shuffle=True,
        seed=42
    )

    val_ds = tf.keras.utils.image_dataset_from_directory(
        VAL_DIR,
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        label_mode='int',
        shuffle=False
    )

    test_ds = tf.keras.utils.image_dataset_from_directory(
        TEST_DIR,
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        label_mode='int',
        shuffle=False
    )

    class_names = train_ds.class_names
    num_classes = len(class_names)

    print(f"Found {num_classes} classes: {class_names}")
    print(f"Train: {train_ds.cardinality().numpy()} batches")
    print(f"Validation: {val_ds.cardinality().numpy()} batches")
    print(f"Test: {test_ds.cardinality().numpy()} batches")

    return train_ds, val_ds, test_ds, class_names, num_classes


def build_model(num_classes):
    """Build MobileNetV2 transfer learning model with custom classification head."""
    base_model = MobileNetV2(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,
        weights='imagenet'
    )

    # Freeze the base model layers
    base_model.trainable = False

    # Build the full model
    model = models.Sequential([
        base_model,
        layers.GlobalAveragePooling2D(),
        layers.Dropout(0.3),
        layers.Dense(128, activation='relu'),
        layers.Dropout(0.2),
        layers.Dense(num_classes, activation='softmax')
    ])

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )

    return model


def train(model, train_ds, val_ds):
    """Train the model with early stopping and learning rate reduction."""
    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor='val_loss',
            patience=3,
            restore_best_weights=True
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=2,
            min_lr=1e-7
        )
    ]

    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=EPOCHS,
        callbacks=callbacks
    )

    return history


def evaluate(model, test_ds, class_names):
    """Evaluate model on test set and print classification report."""
    # Get predictions
    y_pred = []
    y_true = []

    for images, labels in test_ds:
        predictions = model.predict(images, verbose=0)
        y_pred.extend(np.argmax(predictions, axis=1))
        y_true.extend(labels.numpy())

    y_pred = np.array(y_pred)
    y_true = np.array(y_true)

    # Overall accuracy
    test_loss, test_acc = model.evaluate(test_ds, verbose=0)
    print(f"\n{'='*60}")
    print(f"TEST ACCURACY: {test_acc:.4f} ({test_acc*100:.2f}%)")
    print(f"TEST LOSS: {test_loss:.4f}")
    print(f"{'='*60}")

    # Classification report
    print("\nCLASSIFICATION REPORT:")
    print(classification_report(y_true, y_pred, target_names=class_names))

    return test_acc


def save_model(model, class_names):
    """Save the trained model and class labels."""
    os.makedirs(MODELS_DIR, exist_ok=True)

    model_path = os.path.join(MODELS_DIR, 'crop_identifier.h5')
    model.save(model_path)
    print(f"\nModel saved to: {model_path}")

    labels_path = os.path.join(MODELS_DIR, 'class_labels.json')
    with open(labels_path, 'w') as f:
        json.dump(class_names, f, indent=2)
    print(f"Class labels saved to: {labels_path}")


def main():
    print("=" * 60)
    print("CROP IMAGE RECOGNITION - MobileNetV2 Transfer Learning")
    print("=" * 60)

    # Load data
    print("\n[1/4] Loading datasets...")
    train_ds, val_ds, test_ds, class_names, num_classes = load_datasets()

    # Build model
    print("\n[2/4] Building MobileNetV2 model...")
    model = build_model(num_classes)
    model.summary()

    # Train
    print("\n[3/4] Training model...")
    history = train(model, train_ds, val_ds)

    # Evaluate
    print("\n[4/4] Evaluating on test set...")
    test_acc = evaluate(model, test_ds, class_names)

    # Save
    save_model(model, class_names)

    print("\n" + "=" * 60)
    print("TRAINING COMPLETE")
    print(f"Final Test Accuracy: {test_acc*100:.2f}%")
    print("=" * 60)


if __name__ == '__main__':
    main()
