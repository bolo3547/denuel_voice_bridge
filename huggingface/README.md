---
title: Denuel Voice Bridge
emoji: �
colorFrom: teal
colorTo: indigo
sdk: gradio
sdk_version: 4.44.0
app_file: app.py
pinned: false
license: mit
---

# 🌉 Denuel Voice Bridge

AI-powered speech therapy companion using voice cloning technology to help people with cleft palate develop clearer speech.

## Features

- 🎤 **Speech-to-Text**: Transcribe audio using OpenAI Whisper
- 🔊 **Text-to-Speech**: Synthesize speech with XTTS v2
- 🎭 **Voice Cloning**: Clone voices for personalized speech synthesis  
- 📊 **Voice Comparison**: Compare voice samples for similarity
- 🔌 **REST API**: Full API for mobile app integration

## API Usage

### Process Audio
```python
from gradio_client import Client

client = Client("YOUR_USERNAME/denuel-voice-bridge")

# Process audio (transcription + enhancement)
result = client.predict(
    audio_base64="<base64_encoded_audio>",
    format="wav",
    api_name="/process_audio"
)
```

### Synthesize Speech
```python
result = client.predict(
    text="Hello, how are you?",
    language="en",
    voice_base64="<optional_voice_sample>",
    api_name="/synthesize"
)
```

## Flutter Integration

Update `VoiceBridgeService` with your Space URL:

```dart
static const String _baseUrl = 'https://YOUR_USERNAME-denuel-voice-bridge.hf.space';
```

## Built With

- [OpenAI Whisper](https://github.com/openai/whisper) - Speech recognition
- [Coqui TTS (XTTS v2)](https://github.com/coqui-ai/TTS) - Voice synthesis & cloning
- [Gradio](https://gradio.app) - Web interface

## License

MIT License - Use responsibly and ethically.
