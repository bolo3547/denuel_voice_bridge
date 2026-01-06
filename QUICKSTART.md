# Denuel Voice Bridge - Quick Start Guide

## 🚀 New Features Added

Your Voice Bridge now includes powerful new capabilities:

### 1. 🎛️ Audio Enhancement
Clean up recordings automatically with noise reduction, normalization, and clarity boost.

```python
from ai.utils import AudioEnhancer

enhancer = AudioEnhancer()
clean_audio = enhancer.full_enhance(noisy_audio)
```

### 2. 📊 Voice Analysis
Analyze voice characteristics including pitch, energy, speaking rate, and quality.

```python
from ai.utils import VoiceAnalyzer

analyzer = VoiceAnalyzer()
analysis = analyzer.analyze(audio, text="Hello world")
analyzer.print_analysis(analysis)

# Compare two voices
similarity = analyzer.compare_voices(audio1, audio2)
```

### 3. 📁 Voice Profile Manager
Save and manage multiple voice profiles for cloning.

```python
from ai.utils import VoiceProfileManager

manager = VoiceProfileManager()
profile = manager.create_profile("My Voice", language="en")
manager.add_sample(profile.id, audio_recording)
manager.print_profiles()
```

### 4. 🌐 REST API Server
Full API server for integration with mobile apps and web clients.

```bash
# Start the server
cd denuel_voice_bridge
python ai/api/server.py

# Or with hot-reload
uvicorn ai.api.server:app --reload --host 0.0.0.0 --port 8000
```

**API Endpoints:**
- `POST /transcribe` - Audio to text
- `POST /synthesize` - Text to audio with voice cloning
- `POST /clone` - Full pipeline (record → transcribe → clone)
- `POST /enhance` - Audio enhancement
- `POST /analyze` - Voice analysis
- `GET /profiles` - List voice profiles
- `WS /ws/stream` - Real-time streaming

**API Documentation:** http://localhost:8000/docs

### 5. 🎭 Emotion & Style Transfer
Add emotional tone to synthesized speech.

```python
pipeline = VoiceToTextToVoiceV2()
pipeline.emotion = "happy"  # happy, sad, angry, calm, excited, whisper
result = pipeline.run_pipeline()
```

### 6. 🌍 Multi-Language Support
Clone your voice across 16+ languages.

```python
pipeline = VoiceToTextToVoiceV2()
pipeline.source_language = "en"
pipeline.target_language = "es"  # Spanish output
result = pipeline.run_pipeline()
```

**Supported Languages:**
en, es, fr, de, it, pt, pl, tr, ru, nl, cs, ar, zh, ja, ko, hi

### 7. ⚡ Real-Time Streaming
Stream audio for real-time voice conversion.

```python
pipeline = VoiceToTextToVoiceV2()

def on_result(text, audio):
    print(f"Transcribed: {text}")
    # Play or send audio...

pipeline.start_streaming(callback=on_result)
```

---

## 📱 Flutter Integration

Connect your Flutter app to the API:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class VoiceBridgeAPI {
  final String baseUrl;
  
  VoiceBridgeAPI({this.baseUrl = 'http://localhost:8000'});
  
  Future<String> transcribe(List<int> audioBytes) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transcribe'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'audio_base64': base64Encode(audioBytes),
        'language': 'en',
      }),
    );
    
    final data = jsonDecode(response.body);
    return data['text'];
  }
  
  Future<List<int>> synthesize(String text, {String? profileId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/synthesize'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
        'voice_profile_id': profileId,
      }),
    );
    
    final data = jsonDecode(response.body);
    return base64Decode(data['audio_base64']);
  }
}
```

---

## 🏃 Running the Enhanced Pipeline

### Interactive Mode (Recommended)
```bash
python ai/pipelines/voice_to_text_to_voice_v2.py -i
```

### Command Line
```bash
# Basic usage
python ai/pipelines/voice_to_text_to_voice_v2.py

# With options
python ai/pipelines/voice_to_text_to_voice_v2.py \
  --duration 10 \
  --source-lang en \
  --target-lang es \
  --emotion happy \
  --voice path/to/sample.wav

# Text-to-speech only
python ai/pipelines/voice_to_text_to_voice_v2.py -t "Hello world"
```

---

## 📦 Install New Dependencies

```bash
pip install -r requirements.txt
```

Or individually:
```bash
pip install fastapi uvicorn python-multipart websockets noisereduce
```

---

## 🗂️ New Project Structure

```
ai/
├── api/
│   ├── __init__.py
│   └── server.py          # REST API + WebSocket server
├── pipelines/
│   ├── voice_to_text_to_voice.py     # Original pipeline
│   └── voice_to_text_to_voice_v2.py  # Enhanced pipeline
└── utils/
    ├── __init__.py
    ├── audio_enhancer.py      # Audio cleanup
    ├── voice_analyzer.py      # Voice analysis
    └── voice_profile_manager.py  # Profile management
```

---

## 🎯 What's Next?

1. **Test the API** - Start the server and try the Swagger docs
2. **Create a voice profile** - Record samples and save them
3. **Integrate with Flutter** - Connect your mobile app
4. **Try different emotions** - Experiment with styles
5. **Test multi-language** - Clone your voice in other languages

Happy voice cloning! 🎙️
