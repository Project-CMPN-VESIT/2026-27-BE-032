# -*- coding: utf-8 -*-
"""
DL Model - ViT & ResNet for APTOS Dataset
GPU Accelerated, Windows-compatible, optimized PyTorch training script.
"""

import os
import sys
import shutil
import zipfile
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from tqdm import tqdm
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, mean_squared_error

import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from torchvision import datasets, transforms, models
from transformers import ViTForImageClassification

# -----------------------------------------------------------------------------
# 1. PATH RESOLUTION & GPU HARDWARE DETECTION
# -----------------------------------------------------------------------------
print("\n==================================================")
print(" 🚀 STAGE 1: ENVIRONMENT & HARDWARE SETUP ")
print("==================================================")

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATASET_DIR = os.path.join(BASE_DIR, "dataset")
TRAINING_DIR = os.path.join(BASE_DIR, "training")

TRAIN_CSV = os.path.join(DATASET_DIR, "train.csv")
TRAIN_IMAGES_DIR = os.path.join(DATASET_DIR, "train_images")
TEST_IMAGES_DIR = os.path.join(DATASET_DIR, "test_images")

PROCESSED_DIR = os.path.join(DATASET_DIR, "aptos_processed")
PROCESSED_TRAIN_DIR = os.path.join(PROCESSED_DIR, "train")

FINAL_DIR = os.path.join(DATASET_DIR, "aptos_final")
FINAL_TRAIN_DIR = os.path.join(FINAL_DIR, "train")
FINAL_VAL_DIR = os.path.join(FINAL_DIR, "val")

# Ensure required folders exist
os.makedirs(DATASET_DIR, exist_ok=True)
os.makedirs(TRAINING_DIR, exist_ok=True)
os.makedirs(PROCESSED_DIR, exist_ok=True)
os.makedirs(FINAL_DIR, exist_ok=True)

# GPU Detection & Performance Optimization
use_cuda = torch.cuda.is_available()
device = torch.device("cuda" if use_cuda else "cpu")

print(f"CUDA Available     : {use_cuda}")
if use_cuda:
    print(f"GPU Device Name    : {torch.cuda.get_device_name(0)}")
    print(f"CUDA Device Count  : {torch.cuda.device_count()}")
    torch.backends.cudnn.benchmark = True
    num_workers = 2
    pin_memory = True
else:
    print("Running on CPU")
    num_workers = 0
    pin_memory = False

# -----------------------------------------------------------------------------
# 2. DATASET LOADING & VERIFICATION
# -----------------------------------------------------------------------------
print("\n==================================================")
print(" 📂 STAGE 2: DATASET LOADING & VERIFICATION ")
print("==================================================")

if not os.path.exists(TRAIN_CSV):
    print(f"ERROR: Dataset CSV file not found at: '{TRAIN_CSV}'")
    sys.exit(1)

if not os.path.exists(TRAIN_IMAGES_DIR):
    print(f"ERROR: Training images directory not found at: '{TRAIN_IMAGES_DIR}'")
    sys.exit(1)

print(f"✅ Found train.csv at: {TRAIN_CSV}")
print(f"✅ Found train_images/ at: {TRAIN_IMAGES_DIR}")

# -----------------------------------------------------------------------------
# 3. CSV PROCESSING & FOLDER STRUCTURE SETUP
# -----------------------------------------------------------------------------
print("\n==================================================")
print(" 🔄 STAGE 3: CSV PROCESSING & FOLDER SETUP ")
print("==================================================")

df = pd.read_csv(TRAIN_CSV)
os.makedirs(PROCESSED_TRAIN_DIR, exist_ok=True)
for i in range(5):
    os.makedirs(os.path.join(PROCESSED_TRAIN_DIR, str(i)), exist_ok=True)

copied_count = 0
print("Organizing dataset images into class subfolders...")
for _, row in tqdm(df.iterrows(), total=len(df), desc="Classifying Images"):
    img_name = str(row["id_code"])
    if not img_name.endswith(".png"):
        img_name += ".png"
    label = str(row["diagnosis"])

    src = os.path.join(TRAIN_IMAGES_DIR, img_name)
    dst = os.path.join(PROCESSED_TRAIN_DIR, label, img_name)

    if os.path.exists(src):
        shutil.copy(src, dst)
        copied_count += 1

print(f"CSV → Folders conversion completed ({copied_count} images mapped)!")

# -----------------------------------------------------------------------------
# 4. TRAIN-VALIDATION SPLIT
# -----------------------------------------------------------------------------
print("\n==================================================")
print(" ✂️ STAGE 4: TRAIN / VALIDATION SPLIT ")
print("==================================================")

os.makedirs(FINAL_TRAIN_DIR, exist_ok=True)
os.makedirs(FINAL_VAL_DIR, exist_ok=True)

for cls in os.listdir(PROCESSED_TRAIN_DIR):
    cls_path = os.path.join(PROCESSED_TRAIN_DIR, cls)
    if not os.path.isdir(cls_path):
        continue

    imgs = os.listdir(cls_path)
    if not imgs:
        continue

    train_imgs, val_imgs = train_test_split(imgs, test_size=0.2, random_state=42)

    os.makedirs(os.path.join(FINAL_TRAIN_DIR, cls), exist_ok=True)
    os.makedirs(os.path.join(FINAL_VAL_DIR, cls), exist_ok=True)

    for img in train_imgs:
        shutil.copy(os.path.join(cls_path, img), os.path.join(FINAL_TRAIN_DIR, cls, img))

    for img in val_imgs:
        shutil.copy(os.path.join(cls_path, img), os.path.join(FINAL_VAL_DIR, cls, img))

print("Train-Validation split completed!")

# DataLoader initialization
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
])

train_data = datasets.ImageFolder(FINAL_TRAIN_DIR, transform=transform)
val_data = datasets.ImageFolder(FINAL_VAL_DIR, transform=transform)

train_loader = DataLoader(
    train_data, batch_size=16, shuffle=True,
    num_workers=num_workers, pin_memory=pin_memory
)
val_loader = DataLoader(
    val_data, batch_size=16, shuffle=False,
    num_workers=num_workers, pin_memory=pin_memory
)

print(f"Identified Classes: {train_data.classes}")

# -----------------------------------------------------------------------------
# 5. VISION TRANSFORMER (ViT) MODEL TRAINING
# -----------------------------------------------------------------------------
print("\n==================================================")
print(" 🤖 STAGE 5: ViT (VISION TRANSFORMER) TRAINING ")
print("==================================================")

vit_model = ViTForImageClassification.from_pretrained(
    "google/vit-base-patch16-224",
    num_labels=5,
    ignore_mismatched_sizes=True
)
vit_model.to(device)

print(f"ViT Model running on device: {next(vit_model.parameters()).device}")

criterion = nn.CrossEntropyLoss()
vit_optimizer = torch.optim.Adam(vit_model.parameters(), lr=1e-4)

EPOCHS = 3
vit_train_losses = []
vit_val_losses = []

for epoch in range(EPOCHS):
    vit_model.train()
    train_loss = 0.0

    pbar_train = tqdm(train_loader, desc=f"ViT Epoch {epoch+1}/{EPOCHS} [Train]")
    for images, labels in pbar_train:
        images = images.to(device, non_blocking=True)
        labels = labels.to(device, non_blocking=True)

        outputs = vit_model(images).logits
        loss = criterion(outputs, labels)

        vit_optimizer.zero_grad()
        loss.backward()
        vit_optimizer.step()

        train_loss += loss.item()
        pbar_train.set_postfix({"batch_loss": f"{loss.item():.4f}"})

    avg_train = train_loss / len(train_loader)
    vit_train_losses.append(avg_train)

    vit_model.eval()
    val_loss = 0.0

    pbar_val = tqdm(val_loader, desc=f"ViT Epoch {epoch+1}/{EPOCHS} [Val]")
    with torch.no_grad():
        for images, labels in pbar_val:
            images = images.to(device, non_blocking=True)
            labels = labels.to(device, non_blocking=True)

            outputs = vit_model(images).logits
            loss = criterion(outputs, labels)
            val_loss += loss.item()
            pbar_val.set_postfix({"batch_loss": f"{loss.item():.4f}"})

    avg_val = val_loss / len(val_loader)
    vit_val_losses.append(avg_val)

    print(f"Summary -> ViT Epoch {epoch+1}: Train Loss = {avg_train:.4f}, Val Loss = {avg_val:.4f}")

# Save ViT Model
print("\nSaving ViT Model Artifacts...")
vit_dir = os.path.join(TRAINING_DIR, "retina_vit")
os.makedirs(vit_dir, exist_ok=True)
vit_model.save_pretrained(vit_dir)

vit_pth_path = os.path.join(TRAINING_DIR, "retina_vit.pth")
torch.save(vit_model.state_dict(), vit_pth_path)
print(f"✅ Saved retina_vit/ and retina_vit.pth to: '{TRAINING_DIR}'")

# Evaluate ViT Metrics
vit_model.eval()
y_true_vit = []
y_pred_vit = []

with torch.no_grad():
    for images, labels in tqdm(val_loader, desc="Evaluating ViT Metrics"):
        images = images.to(device, non_blocking=True)
        outputs = vit_model(images).logits
        preds = torch.argmax(outputs, dim=1).cpu().numpy()

        y_pred_vit.extend(preds)
        y_true_vit.extend(labels.numpy())

vit_accuracy = accuracy_score(y_true_vit, y_pred_vit)
vit_precision = precision_score(y_true_vit, y_pred_vit, average='weighted', zero_division=0)
vit_recall = recall_score(y_true_vit, y_pred_vit, average='weighted', zero_division=0)
vit_f1 = f1_score(y_true_vit, y_pred_vit, average='weighted', zero_division=0)
vit_mse = mean_squared_error(y_true_vit, y_pred_vit)

print(f"ViT Accuracy : {vit_accuracy:.4f}")
print(f"ViT Precision: {vit_precision:.4f}")
print(f"ViT Recall   : {vit_recall:.4f}")
print(f"ViT F1 Score : {vit_f1:.4f}")
print(f"ViT MSE      : {vit_mse:.4f}")

# Plot ViT Loss Graph
plt.figure(figsize=(8, 5))
plt.plot(vit_train_losses, label="Train Loss", marker='o')
plt.plot(vit_val_losses, label="Validation Loss", marker='s')
plt.xlabel("Epoch")
plt.ylabel("Loss")
plt.title("ViT Epoch vs Loss")
plt.legend()
plt.grid(True)
plt.show()

# -----------------------------------------------------------------------------
# 6. RESNET-18 MODEL TRAINING
# -----------------------------------------------------------------------------
print("\n==================================================")
print(" 🧠 STAGE 6: RESNET-18 MODEL TRAINING ")
print("==================================================")

resnet_model = models.resnet18(weights=models.ResNet18_Weights.DEFAULT)
resnet_model.fc = nn.Linear(resnet_model.fc.in_features, 5)
resnet_model.to(device)

print(f"ResNet Model running on device: {next(resnet_model.parameters()).device}")

resnet_optimizer = torch.optim.Adam(resnet_model.parameters(), lr=1e-4)
resnet_train_losses = []

for epoch in range(EPOCHS):
    resnet_model.train()
    total_loss = 0.0

    pbar_resnet = tqdm(train_loader, desc=f"ResNet Epoch {epoch+1}/{EPOCHS}")
    for images, labels in pbar_resnet:
        images = images.to(device, non_blocking=True)
        labels = labels.to(device, non_blocking=True)

        outputs = resnet_model(images)
        loss = criterion(outputs, labels)

        resnet_optimizer.zero_grad()
        loss.backward()
        resnet_optimizer.step()

        total_loss += loss.item()
        pbar_resnet.set_postfix({"batch_loss": f"{loss.item():.4f}"})

    avg_resnet_loss = total_loss / len(train_loader)
    resnet_train_losses.append(avg_resnet_loss)
    print(f"Summary -> ResNet Epoch {epoch+1}: Train Loss = {avg_resnet_loss:.4f}")

resnet_pth_path = os.path.join(TRAINING_DIR, "retina_resnet18.pth")
torch.save(resnet_model.state_dict(), resnet_pth_path)
print(f"✅ Saved retina_resnet18.pth to: '{resnet_pth_path}'")

# Evaluate ResNet Metrics
resnet_model.eval()
y_true_resnet = []
y_pred_resnet = []

with torch.no_grad():
    for images, labels in tqdm(val_loader, desc="Evaluating ResNet Metrics"):
        images = images.to(device, non_blocking=True)
        outputs = resnet_model(images)
        preds = torch.argmax(outputs, dim=1).cpu().numpy()

        y_pred_resnet.extend(preds)
        y_true_resnet.extend(labels.numpy())

resnet_accuracy = accuracy_score(y_true_resnet, y_pred_resnet)
resnet_precision = precision_score(y_true_resnet, y_pred_resnet, average='weighted', zero_division=0)
resnet_recall = recall_score(y_true_resnet, y_pred_resnet, average='weighted', zero_division=0)
resnet_f1 = f1_score(y_true_resnet, y_pred_resnet, average='weighted', zero_division=0)
resnet_mse = mean_squared_error(y_true_resnet, y_pred_resnet)

print(f"ResNet Accuracy : {resnet_accuracy:.4f}")
print(f"ResNet Precision: {resnet_precision:.4f}")
print(f"ResNet Recall   : {resnet_recall:.4f}")
print(f"ResNet F1 Score : {resnet_f1:.4f}")

# -----------------------------------------------------------------------------
# 7. MODEL COMPARISON & GRAPH GENERATION
# -----------------------------------------------------------------------------
print("\n==================================================")
print(" 📊 STAGE 7: MODEL COMPARISON & PERFORMANCE GRAPHS ")
print("==================================================")

comparison_df = pd.DataFrame({
    "Model": ["ResNet-18", "ViT"],
    "Accuracy": [resnet_accuracy, vit_accuracy],
    "Precision": [resnet_precision, vit_precision],
    "Recall": [resnet_recall, vit_recall],
    "F1 Score": [resnet_f1, vit_f1],
    "Train Loss (Final)": [resnet_train_losses[-1], vit_train_losses[-1]],
    "Val Loss (Final)": ["N/A", vit_val_losses[-1]],
    "MSE": [resnet_mse, vit_mse]
})
print("\n--- Model Performance Comparison ---")
print(comparison_df.to_string(index=False))

# Loss Comparison Plot
epochs_range = list(range(1, EPOCHS + 1))
plt.figure(figsize=(8, 5))
plt.plot(epochs_range, resnet_train_losses, label="ResNet Train Loss", marker='o')
plt.plot(epochs_range, vit_train_losses, label="ViT Train Loss", marker='s')
plt.plot(epochs_range, vit_val_losses, label="ViT Val Loss", marker='^')
plt.xlabel("Epochs")
plt.ylabel("Loss")
plt.title("ResNet vs ViT Loss Comparison")
plt.legend()
plt.grid(True)
plt.show()

# Metric Bar Graph
metric_labels = ["Accuracy", "Precision", "Recall", "F1"]
resnet_metrics = [resnet_accuracy, resnet_precision, resnet_recall, resnet_f1]
vit_metrics = [vit_accuracy, vit_precision, vit_recall, vit_f1]

x = np.arange(len(metric_labels))
width = 0.35

plt.figure(figsize=(8, 5))
plt.bar(x - width / 2, resnet_metrics, width, label="ResNet", color='navy')
plt.bar(x + width / 2, vit_metrics, width, label="ViT", color='teal')
plt.xlabel("Metrics")
plt.ylabel("Score")
plt.title("ResNet vs ViT Performance")
plt.xticks(x, metric_labels)
plt.ylim(0, 1.1)
plt.legend()
plt.grid(axis='y', linestyle='--', alpha=0.7)
plt.show()

# -----------------------------------------------------------------------------
# 8. U-NET MODEL DEFINITION & WEIGHT SAVING
# -----------------------------------------------------------------------------
print("\n==================================================")
print(" 🔬 STAGE 8: U-NET MODEL DEFINITION & SAVING ")
print("==================================================")

class UNet(nn.Module):
    def __init__(self):
        super(UNet, self).__init__()

        def conv_block(in_c, out_c):
            return nn.Sequential(
                nn.Conv2d(in_c, out_c, 3, padding=1),
                nn.ReLU(inplace=True),
                nn.Conv2d(out_c, out_c, 3, padding=1),
                nn.ReLU(inplace=True)
            )

        # Encoder
        self.enc1 = conv_block(3, 64)
        self.pool1 = nn.MaxPool2d(2)

        self.enc2 = conv_block(64, 128)
        self.pool2 = nn.MaxPool2d(2)

        self.enc3 = conv_block(128, 256)
        self.pool3 = nn.MaxPool2d(2)

        self.enc4 = conv_block(256, 512)
        self.pool4 = nn.MaxPool2d(2)

        # Bottleneck
        self.bottleneck = conv_block(512, 1024)

        # Decoder
        self.up4 = nn.ConvTranspose2d(1024, 512, 2, stride=2)
        self.dec4 = conv_block(1024, 512)

        self.up3 = nn.ConvTranspose2d(512, 256, 2, stride=2)
        self.dec3 = conv_block(512, 256)

        self.up2 = nn.ConvTranspose2d(256, 128, 2, stride=2)
        self.dec2 = conv_block(256, 128)

        self.up1 = nn.ConvTranspose2d(128, 64, 2, stride=2)
        self.dec1 = conv_block(128, 64)

        self.out = nn.Conv2d(64, 1, 1)

    def forward(self, x):
        e1 = self.enc1(x)
        e2 = self.enc2(self.pool1(e1))
        e3 = self.enc3(self.pool2(e2))
        e4 = self.enc4(self.pool3(e3))

        b = self.bottleneck(self.pool4(e4))

        d4 = self.up4(b)
        d4 = torch.cat([d4, e4], dim=1)
        d4 = self.dec4(d4)

        d3 = self.up3(d4)
        d3 = torch.cat([d3, e3], dim=1)
        d3 = self.dec3(d3)

        d2 = self.up2(d3)
        d2 = torch.cat([d2, e2], dim=1)
        d2 = self.dec2(d2)

        d1 = self.up1(d2)
        d1 = torch.cat([d1, e1], dim=1)
        d1 = self.dec1(d1)

        return torch.sigmoid(self.out(d1))

# Instantiate and Save U-Net
unet = UNet()
unet_pth_path = os.path.join(TRAINING_DIR, "retina_unet.pth")
torch.save(unet.state_dict(), unet_pth_path)

print(f"✅ U-Net model saved successfully at: '{unet_pth_path}'")
print("\n==================================================")
print(" 🎉 ALL MODEL TRAINING & SAVING STAGES COMPLETE! ")
print("==================================================")
