---
title: Denuel Voice Bridge
emoji: 🎙️
colorFrom: purple
colorTo: blue
sdk: gradio
sdk_version: 4.0.0
app_file: app.py
pinned: false
license: mit
hardware: gpu-basic
---

# 🎙️ Denuel Voice Bridge

Voice cloning, transcription, and synthesis powered by **Whisper** and **XTTS v2**.

## Features

- **🎭 Voice Cloning** - Clone any voice from a sample
- **📝 Transcription** - Speech-to-text with Whisper
- **🔊 Synthesis** - Text-to-speech with voice cloning
- **🌍 Multi-language** - 16 languages supported
- **🎭 Emotion Styles** - Add emotional tone to speech
- **📊 Voice Comparison** - Compare voice similarity

## Usage

1. **Voice Clone Tab**: Record or upload audio → Get cloned output
2. **Transcribe Tab**: Convert speech to text
3. **Synthesize Tab**: Convert text to speech (with optional voice cloning)
4. **Compare Tab**: Compare two voice samples

## API

This Space provides an API for integration with your apps:

```python
from gradio_client import Client

client = Client("YOUR_USERNAME/denuel-voice-bridge")

# Clone voice
result = client.predict(
    audio_file,      # Input audio
    "English",       # Language
    "neutral",       # Emotion
    api_name="/clone_voice"
)
```

## Models Used

- **Whisper Base** - OpenAI's speech recognition
- **XTTS v2** - Coqui's voice cloning TTS

## License

MIT License - Use responsibly and ethically.

## Links

- [GitHub Repository](https://github.com/YOUR_USERNAME/denuel_voice_bridge)
- [Whisper](https://github.com/openai/whisper)
- [XTTS](https://github.com/coqui-ai/TTS)
