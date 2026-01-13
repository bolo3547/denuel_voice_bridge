# 🚀 Deploy to Hugging Face Spaces

## Step 1: Create a Hugging Face Account

1. Go to [https://huggingface.co/join](https://huggingface.co/join)
2. Create a free account

## Step 2: Create a New Space

1. Go to [https://huggingface.co/new-space](https://huggingface.co/new-space)
2. Configure your Space:
   - **Owner**: Your username
   - **Space name**: `denuel-voice-bridge`
   - **SDK**: `Gradio`
   - **Hardware**: `GPU - T4 small` (required for AI models)
   - **Visibility**: Public or Private

3. Click **Create Space**

## Step 3: Upload Files

### Option A: Web Upload (Easiest)

1. Go to your Space: `https://huggingface.co/spaces/YOUR_USERNAME/denuel-voice-bridge`
2. Click the **Files** tab
3. Click **Add file** → **Upload files**
4. Upload these files from the `huggingface/` folder:
   - `app.py`
   - `requirements.txt`
   - `README.md`

### Option B: Git Push

```bash
# Clone your Space
git clone https://huggingface.co/spaces/YOUR_USERNAME/denuel-voice-bridge
cd denuel-voice-bridge

# Copy files
cp ../huggingface/app.py .
cp ../huggingface/requirements.txt .
cp ../huggingface/README.md .

# Push
git add .
git commit -m "Deploy Denuel Voice Bridge"
git push
```

## Step 4: Wait for Build

- The Space will automatically build (5-10 minutes)
- Watch the logs at your Space URL
- Once running, you'll see the Gradio interface

## Step 5: Get Your API URL

Your Space URL will be:
```
https://YOUR_USERNAME-denuel-voice-bridge.hf.space
```

## Step 6: Configure Flutter App

1. Open the app
2. Go to **Settings** → **AI Backend**
3. Set the Backend URL to your Space URL
4. Click **Test Connection**

## 🎉 Done!

Your speech therapy app now has AI-powered:
- Speech transcription (Whisper)
- Voice synthesis (XTTS v2)
- Voice cloning
- Audio enhancement

## Troubleshooting

### Space not building?
- Check the logs in the Space's "Logs" tab
- Make sure you selected GPU hardware

### Connection failing?
- Ensure the Space is running (green status)
- Check if the URL is correct
- Try the Gradio interface directly first

### Models loading slowly?
- First request loads models (~30-60 seconds)
- Subsequent requests are faster
