# Denuel Voice Bridge

A personal voice cloning and synthesis system that captures your unique voice characteristics and enables real-time voice transformation.

## 🎯 Overview

Denuel Voice Bridge creates a "voice bridge" between your natural speech and AI-powered voice synthesis. Record your voice, train a personalized model, and use it to:

- **Preserve your voice** for future use
- **Real-time voice conversion** via hardware button (ESP32)
- **Text-to-speech** with your cloned voice
- **Mobile app** for easy recording and playback

## 🏗️ Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Voice Input    │────▶│  STT (Whisper)  │────▶│  Text Content   │
│  (Microphone)   │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └────────┬────────┘
                                                         │
                                                         ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Voice Output   │◀────│  TTS (XTTS)     │◀────│  Voice Profile  │
│  (Speaker)      │     │  + Your Voice   │     │  (Embeddings)   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## 📁 Project Structure

```
denuel_voice_bridge/
├── ai/
│   ├── pipelines/          # Voice processing pipelines
│   │   ├── voice_to_text_to_voice.py
│   │   └── voice_to_voice.py
│   ├── stt/whisper/        # Speech-to-text (Whisper)
│   ├── tts/xtts/           # Text-to-speech (XTTS v2)
│   └── voice_conversion/   # Future voice conversion models
├── app/
│   ├── mobile/flutter/     # Flutter mobile app
│   └── shared/             # Shared utilities
├── data/
│   ├── embeddings/         # Voice embeddings/profiles
│   ├── voice_profile_clean/# Processed voice samples
│   └── voice_profile_raw/  # Raw recordings
├── docs/                   # Documentation
├── hardware/
│   └── esp32_voice_button/ # ESP32 push-to-talk hardware
├── security/               # Privacy & encryption docs
└── tools/
    ├── audio_tools/        # Audio processing utilities
    └── dataset_tools/      # Voice dataset management
```

## 🚀 Quick Start

### 1. Setup Environment

```bash
# Create and activate virtual environment
python -m venv venv
.\venv\Scripts\Activate.ps1  # Windows
source venv/bin/activate      # Linux/Mac

# Install dependencies
pip install -r requirements.txt
```

### 2. Collect Voice Samples

```bash
# Record voice samples for training
python tools/audio_tools/voice_recorder.py
```

### 3. Run Voice Pipeline

```bash
# Test the voice-to-text-to-voice pipeline
python ai/pipelines/voice_to_text_to_voice.py
```

## 🔧 Requirements

- Python 3.12+
- CUDA-capable GPU (recommended for real-time processing)
- Microphone for voice recording
- ~8GB VRAM for XTTS model

## 📦 Core Dependencies

- **PyTorch** - Deep learning framework
- **OpenAI Whisper** - Speech-to-text
- **Coqui TTS (XTTS)** - Text-to-speech with voice cloning
- **sounddevice** - Audio recording/playback
- **librosa** - Audio processing

## 🔒 Privacy

Your voice data stays local. See [security/data_policy.md](security/data_policy.md) for details.

## 📄 License

Personal use project by Denuel Inambao.
