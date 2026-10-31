import os
import sys
import random
import numpy as np
import matplotlib.pyplot as plt
from PIL import Image

import tensorflow as tf
from tensorflow.keras import layers, models
# pyrefly: ignore [missing-import]
from tensorflow.keras.utils import load_img, img_to_array
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, confusion_matrix, classification_report

# -----------------------------------------------------------------------------
# 1. PATH RESOLUTION & ENVIRONMENT SETUP
# -----------------------------------------------------------------------------
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATASET_PATH = os.path.join(BASE_DIR, "dataset", "DFU", "Patches")
SAVED_MODEL_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dfu_cnn.h5")

# GPU / CPU Setup
gpus = tf.config.list_physical_devices('GPU')
if gpus:
    try:
        for gpu in gpus:
            tf.config.experimental.set_memory_growth(gpu, True)
        print(f"✅ GPU Available: {gpus}")
    except RuntimeError as e:
        print(f"⚠️ GPU setup error: {e}")
else:
    print("ℹ️ GPU unavailable. Running training on CPU.")

IMAGE_SIZE = (224, 224)
BATCH_SIZE = 32
EPOCHS = 20

# -----------------------------------------------------------------------------
# 2. DATA LOADING & PREPROCESSING
# -----------------------------------------------------------------------------
print(f"\n--- Loading Dataset from: {DATASET_PATH} ---")
if not os.path.exists(DATASET_PATH):
    print(f"ERROR: Dataset path does not exist: '{DATASET_PATH}'")
    sys.exit(1)

class_names = ["Normal(Healthy skin)", "Abnormal(Ulcer)"]
images = []
labels = []

for class_idx, class_name in enumerate(class_names):
    folder_path = os.path.join(DATASET_PATH, class_name)
    if not os.path.exists(folder_path):
        print(f"⚠️ Class directory missing: {folder_path}")
        continue

    valid_exts = ('.png', '.jpg', '.jpeg', '.bmp', '.tif', '.tiff')
    filenames = [f for f in os.listdir(folder_path) if f.lower().endswith(valid_exts)]
    print(f"Loading {len(filenames)} images from: {class_name}")

    for filename in filenames:
        img_path = os.path.join(folder_path, filename)
        try:
            img = load_img(img_path, target_size=IMAGE_SIZE)
            img_arr = img_to_array(img) / 255.0  # Normalize to [0, 1]
            images.append(img_arr)
            labels.append(class_idx)
        except Exception as e:
            print(f"Warning: Failed to load image {img_path}: {e}")

if len(images) == 0:
    print("⚠️ No dataset images found in Patches folder. Generating dummy synthetic dataset for verification...")
    for class_idx in range(2):
        for _ in range(50):
            dummy_img = np.random.rand(224, 224, 3).astype(np.float32)
            images.append(dummy_img)
            labels.append(class_idx)

X = np.array(images, dtype=np.float32)
y = np.array(labels, dtype=np.int32)

print(f"Dataset Loaded Successfully: {X.shape[0]} total samples.")

# Perform Train-Test Split (80% Train, 20% Test)
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

print(f"Training samples: {X_train.shape[0]}, Testing samples: {X_test.shape[0]}")

# -----------------------------------------------------------------------------
# 3. BUILD CUSTOM CNN MODEL
# -----------------------------------------------------------------------------
print("\n--- Building Custom CNN Model ---")
model = models.Sequential([
    layers.Input(shape=(224, 224, 3)),
    # Block 1
    layers.Conv2D(32, (3, 3), padding='same'),
    layers.BatchNormalization(),
    layers.Activation('relu'),
    layers.MaxPooling2D((2, 2)),
    layers.Dropout(0.25),

    # Block 2
    layers.Conv2D(64, (3, 3), padding='same'),
    layers.BatchNormalization(),
    layers.Activation('relu'),
    layers.MaxPooling2D((2, 2)),
    layers.Dropout(0.25),

    # Block 3
    layers.Conv2D(128, (3, 3), padding='same'),
    layers.BatchNormalization(),
    layers.Activation('relu'),
    layers.MaxPooling2D((2, 2)),
    layers.Dropout(0.3),

    # Block 4
    layers.Conv2D(256, (3, 3), padding='same'),
    layers.BatchNormalization(),
    layers.Activation('relu'),
    layers.MaxPooling2D((2, 2)),
    layers.Dropout(0.4),

    # Fully Connected Classifier
    layers.Flatten(),
    layers.Dense(512),
    layers.BatchNormalization(),
    layers.Activation('relu'),
    layers.Dropout(0.5),
    layers.Dense(1, activation='sigmoid')
])

model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=1e-4),
    loss='binary_crossentropy',
    metrics=['accuracy']
)

model.summary()

# -----------------------------------------------------------------------------
# 4. TRAIN MODEL
# -----------------------------------------------------------------------------
print(f"\n--- Training Custom CNN for {EPOCHS} Epochs ---")
history = model.fit(
    X_train, y_train,
    epochs=EPOCHS,
    batch_size=BATCH_SIZE,
    validation_data=(X_test, y_test),
    verbose=1
)

# Save Model
model.save(SAVED_MODEL_PATH)
print(f"\n✅ Model saved successfully as '{SAVED_MODEL_PATH}'")

# -----------------------------------------------------------------------------
# 5. EVALUATION METRICS & PLOTS
# -----------------------------------------------------------------------------
print("\n--- Evaluating Model Metrics ---")
y_pred_probs = model.predict(X_test)
y_pred = (y_pred_probs > 0.5).astype(int).flatten()

acc = accuracy_score(y_test, y_pred)
prec = precision_score(y_test, y_pred, average='binary', zero_division=0)
rec = recall_score(y_test, y_pred, average='binary', zero_division=0)
f1 = f1_score(y_test, y_pred, average='binary', zero_division=0)
cm = confusion_matrix(y_test, y_pred)

print(f"Accuracy : {acc:.4f}")
print(f"Precision: {prec:.4f}")
print(f"Recall   : {rec:.4f}")
print(f"F1 Score : {f1:.4f}")
print("\nConfusion Matrix:")
print(cm)
print("\nClassification Report:")
print(classification_report(y_test, y_pred, target_names=["Normal", "Abnormal"]))

# Plot Accuracy and Loss Curves
plt.figure(figsize=(12, 5))

plt.subplot(1, 2, 1)
plt.plot(history.history['accuracy'], label='Train Accuracy', marker='o')
plt.plot(history.history['val_accuracy'], label='Val Accuracy', marker='s')
plt.title('Custom CNN Model Accuracy')
plt.xlabel('Epoch')
plt.ylabel('Accuracy')
plt.legend()
plt.grid(True)

plt.subplot(1, 2, 2)
plt.plot(history.history['loss'], label='Train Loss', marker='o')
plt.plot(history.history['val_loss'], label='Val Loss', marker='s')
plt.title('Custom CNN Model Loss')
plt.xlabel('Epoch')
plt.ylabel('Loss')
plt.legend()
plt.grid(True)

plt.tight_layout()
plt.show()

# -----------------------------------------------------------------------------
# 6. PREDICT 5 RANDOM TEST IMAGES
# -----------------------------------------------------------------------------
print("\n--- Random Test Predictions (5 Samples) ---")
num_samples = min(5, len(X_test))
random_indices = random.sample(range(len(X_test)), num_samples)

plt.figure(figsize=(15, 3))
for idx, sample_idx in enumerate(random_indices):
    test_img = X_test[sample_idx]
    actual_label = "Normal" if y_test[sample_idx] == 0 else "Abnormal (Ulcer)"
    
    pred_prob = model.predict(np.expand_dims(test_img, axis=0))[0][0]
    pred_label = "Normal" if pred_prob <= 0.5 else "Abnormal (Ulcer)"
    confidence = (1 - pred_prob) if pred_prob <= 0.5 else pred_prob

    print(f"Sample {idx+1}: Actual = {actual_label} | Predicted = {pred_label} (Confidence: {confidence * 100:.2f}%)")

    plt.subplot(1, num_samples, idx + 1)
    plt.imshow(test_img)
    plt.title(f"Pred: {pred_label}\nActual: {actual_label}", fontsize=10)
    plt.axis('off')

plt.tight_layout()
plt.show()
print("\n🎉 DFU Custom CNN Pipeline Execution Complete!")
