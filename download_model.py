import kagglehub
import shutil
import os

# Download latest version
path = kagglehub.model_download("tensorflow/mobilebert/tfLite/metadata")
print("Downloaded to:", path)

# Target path in your Flutter project
target_dir = r"c:\Users\sedat\LedgerZero\assets\models"
os.makedirs(target_dir, exist_ok=True)

# Copy model file
for file in os.listdir(path):
    src = os.path.join(path, file)
    dst = os.path.join(target_dir, file)
    if os.path.isfile(src):
        shutil.copy2(src, dst)
        print(f"Copied: {file} -> {target_dir}")

print("\nModel files are now in:", target_dir)
