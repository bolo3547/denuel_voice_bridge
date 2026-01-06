# Deploying to Hugging Face Spaces
# =================================

# 1. Install Hugging Face CLI
pip install huggingface_hub

# 2. Login to Hugging Face
huggingface-cli login

# 3. Create a new Space (from web UI or CLI)
# Go to: https://huggingface.co/new-space
# - Name: denuel-voice-bridge
# - SDK: Gradio
# - Hardware: GPU (T4 small) - FREE!

# 4. Clone your Space locally
git clone https://huggingface.co/spaces/YOUR_USERNAME/denuel-voice-bridge
cd denuel-voice-bridge

# 5. Copy the files
copy ..\app.py .
copy ..\requirements.txt .
copy ..\README.md .

# 6. Push to Hugging Face
git add .
git commit -m "Initial deployment"
git push

# Your Space will be live at:
# https://huggingface.co/spaces/YOUR_USERNAME/denuel-voice-bridge

# =================================
# Alternative: Deploy from existing repo
# =================================

# If you have your GitHub repo connected:
# 1. Go to Space settings
# 2. Link your GitHub repo
# 3. Set the subdirectory to "huggingface"
# 4. It will auto-deploy on push!
