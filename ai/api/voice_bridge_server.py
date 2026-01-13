"""
DENUEL VOICE BRIDGE - Web API Server
=====================================
REST API for the voice bridge system.

Endpoints:
    POST /process-audio    - Process audio and return clear speech
    POST /process-text     - Process text and return clear speech
    GET  /phrase-memory    - Get phrase memory
    POST /phrase-memory    - Update phrase memory
    GET  /health           - Health check

Run:
    python ai/api/voice_bridge_server.py
"""

import os
import sys
import json
import base64
import tempfile
import wave
from pathlib import Path
from datetime import datetime
from typing import Optional
from io import BytesIO

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

try:
    from flask import Flask, request, jsonify, send_file
    from flask_cors import CORS
except ImportError:
    print("Missing dependencies. Installing...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "flask", "flask-cors"])
    from flask import Flask, request, jsonify, send_file
    from flask_cors import CORS

import numpy as np

# Import the voice bridge
from ai.pipelines.denuel_voice_bridge import (
    DenuelVoiceBridge,
    PhraseMemory,
    PHRASE_MEMORY_PATH
)

# =============================================================================
# FLASK APP
# =============================================================================

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter web

# Global bridge instance (lazy loaded)
_bridge: Optional[DenuelVoiceBridge] = None
_phrase_memory: Optional[PhraseMemory] = None


def get_bridge() -> DenuelVoiceBridge:
    """Get or create the voice bridge instance."""
    global _bridge
    if _bridge is None:
        print("🌉 Initializing DENUEL VOICE BRIDGE...")
        _bridge = DenuelVoiceBridge()
    return _bridge


def get_phrase_memory() -> PhraseMemory:
    """Get or create the phrase memory instance."""
    global _phrase_memory
    if _phrase_memory is None:
        _phrase_memory = PhraseMemory()
    return _phrase_memory


# =============================================================================
# ENDPOINTS
# =============================================================================

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    global _bridge
    return jsonify({
        "status": "ok",
        "service": "DENUEL VOICE BRIDGE",
        "version": "1.0.0",
        "models_loaded": _bridge is not None,
        "ready": _bridge is not None
    })


@app.route('/warmup', methods=['POST'])
def warmup():
    """
    Pre-load AI models to speed up first request.
    Call this when app starts to avoid delay on first recording.
    """
    try:
        print("🔥 Warming up models...")
        bridge = get_bridge()
        
        # The bridge constructor already loads models
        # Just verify they're ready
        models_ready = bridge is not None
        
        return jsonify({
            "success": True,
            "message": "Models loaded and ready",
            "models_ready": models_ready
        })
    except Exception as e:
        print(f"Warmup error: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


@app.route('/process-text', methods=['POST'])
def process_text():
    """
    Process text and return clear speech audio.
    
    Request:
        {
            "text": "Hello world"
        }
    
    Response:
        {
            "success": true,
            "original_text": "Hello world",
            "normalized_text": "Hello world",
            "audio_base64": "base64-encoded-wav-audio",
            "audio_format": "wav"
        }
    """
    try:
        data = request.get_json()
        text = data.get('text', '').strip()
        
        if not text:
            return jsonify({"success": False, "error": "No text provided"}), 400
        
        bridge = get_bridge()
        
        # Apply phrase memory corrections
        phrase_corrected = bridge.phrase_memory.apply_corrections(text)
        
        # Apply word-level normalization
        normalized = bridge.normalizer.normalize(phrase_corrected)
        
        # Generate clear speech
        audio = bridge.generate_clear_speech(text, save=False)
        
        if audio is None:
            return jsonify({"success": False, "error": "Failed to generate audio"}), 500
        
        # Convert to WAV bytes
        audio_bytes = audio_to_wav_bytes(audio)
        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
        
        return jsonify({
            "success": True,
            "original_text": text,
            "normalized_text": normalized,
            "audio_base64": audio_base64,
            "audio_format": "wav"
        })
    
    except Exception as e:
        print(f"Error in process_text: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/process-audio', methods=['POST'])
def process_audio():
    """
    Process audio and return clear speech.
    
    Request:
        {
            "audio_base64": "base64-encoded-audio",
            "audio_format": "webm" | "wav"
        }
    
    Response:
        {
            "success": true,
            "recognized_text": "What was heard",
            "normalized_text": "Corrected version",
            "audio_base64": "base64-encoded-wav-audio",
            "audio_format": "wav"
        }
    """
    try:
        data = request.get_json()
        if data is None:
            return jsonify({"success": False, "error": "Invalid JSON body"}), 400
            
        audio_base64 = data.get('audio_base64', '')
        audio_format = data.get('audio_format', 'webm')
        
        if not audio_base64:
            return jsonify({"success": False, "error": "No audio provided"}), 400
        
        print(f"📥 Received audio: format={audio_format}, base64_length={len(audio_base64)}")
        
        # Decode audio
        try:
            audio_bytes = base64.b64decode(audio_base64)
            print(f"📦 Decoded {len(audio_bytes)} bytes of audio data")
        except Exception as e:
            return jsonify({"success": False, "error": f"Invalid base64 audio: {e}"}), 400
        
        # Convert to numpy array
        audio_array = decode_audio(audio_bytes, audio_format)
        
        if audio_array is None or len(audio_array) == 0:
            return jsonify({"success": False, "error": f"Failed to decode {audio_format} audio. Make sure ffmpeg is installed."}), 400
        
        print(f"🎵 Decoded audio: {len(audio_array)} samples")
        
        bridge = get_bridge()
        
        # Clean the audio
        clean_audio = bridge.clean_audio(audio_array)
        
        # Transcribe
        recognized_text = bridge.understand(clean_audio)
        
        if not recognized_text:
            return jsonify({
                "success": True,
                "recognized_text": "",
                "normalized_text": "",
                "audio_base64": "",
                "message": "No speech detected"
            })
        
        # Generate clear speech
        output_audio = bridge.generate_clear_speech(recognized_text, save=False)
        
        if output_audio is None:
            return jsonify({"success": False, "error": "Failed to generate audio"}), 500
        
        # Convert to WAV bytes
        audio_bytes = audio_to_wav_bytes(output_audio)
        audio_base64_out = base64.b64encode(audio_bytes).decode('utf-8')
        
        return jsonify({
            "success": True,
            "recognized_text": recognized_text,
            "normalized_text": bridge.last_output_text,
            "audio_base64": audio_base64_out,
            "audio_format": "wav"
        })
    
    except Exception as e:
        print(f"Error in process_audio: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/analyze-pronunciation', methods=['POST'])
def analyze_pronunciation():
    """
    Analyze pronunciation and provide feedback.
    
    Request:
        {
            "audio_base64": "base64-encoded-audio",
            "audio_format": "webm" | "wav" | "m4a",
            "target_text": "The text you were trying to say" (optional)
        }
    
    Response:
        {
            "success": true,
            "recognized_text": "What was actually heard",
            "target_text": "What you were trying to say",
            "metrics": {
                "clarityScore": 85.0,
                "nasalityScore": 30.0,
                "pacingScore": 3.2,
                "breathControlScore": 75.0,
                "overallScore": 80.0
            },
            "phonemeErrors": [...],
            "suggestions": [...]
        }
    """
    try:
        data = request.get_json()
        if data is None:
            return jsonify({"success": False, "error": "Invalid JSON body"}), 400
            
        audio_base64 = data.get('audio_base64', '')
        audio_format = data.get('audio_format', 'webm')
        target_text = data.get('target_text', '')
        
        if not audio_base64:
            return jsonify({"success": False, "error": "No audio provided"}), 400
        
        print(f"📥 Analyzing pronunciation: format={audio_format}")
        
        # Decode audio
        try:
            audio_bytes = base64.b64decode(audio_base64)
        except Exception as e:
            return jsonify({"success": False, "error": f"Invalid base64 audio: {e}"}), 400
        
        # Convert to numpy array
        audio_array = decode_audio(audio_bytes, audio_format)
        
        if audio_array is None or len(audio_array) == 0:
            return jsonify({"success": False, "error": "Failed to decode audio"}), 400
        
        bridge = get_bridge()
        
        # Clean the audio
        clean_audio = bridge.clean_audio(audio_array)
        
        # Transcribe what was actually said
        recognized_text = bridge.understand(clean_audio)
        
        if not recognized_text:
            return jsonify({
                "success": True,
                "recognized_text": "",
                "target_text": target_text,
                "metrics": {
                    "clarityScore": 0,
                    "nasalityScore": 0,
                    "pacingScore": 0,
                    "breathControlScore": 0,
                    "overallScore": 0
                },
                "phonemeErrors": [],
                "suggestions": ["No speech detected. Please speak louder and closer to the microphone."],
                "message": "No speech detected"
            })
        
        # Analyze pronunciation quality
        metrics, phoneme_errors, suggestions = analyze_speech_quality(
            audio_array=clean_audio,
            recognized_text=recognized_text,
            target_text=target_text,
            sample_rate=22050
        )
        
        return jsonify({
            "success": True,
            "recognized_text": recognized_text,
            "target_text": target_text,
            "metrics": metrics,
            "phonemeErrors": phoneme_errors,
            "suggestions": suggestions
        })
    
    except Exception as e:
        print(f"Error in analyze_pronunciation: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


def analyze_speech_quality(audio_array, recognized_text, target_text, sample_rate=22050):
    """
    Analyze speech quality and compare to target text.
    Returns metrics, phoneme errors, and suggestions.
    """
    import difflib
    
    # Calculate basic metrics from audio
    duration = len(audio_array) / sample_rate
    
    # Energy analysis (simplified)
    energy = np.abs(audio_array).mean()
    energy_db = 20 * np.log10(energy + 1e-10)
    
    # Estimate clarity based on energy consistency
    if len(audio_array) > sample_rate:
        # Split into chunks and measure variance
        chunk_size = sample_rate // 4
        chunks = [audio_array[i:i+chunk_size] for i in range(0, len(audio_array)-chunk_size, chunk_size)]
        chunk_energies = [np.abs(c).mean() for c in chunks]
        energy_variance = np.std(chunk_energies) / (np.mean(chunk_energies) + 1e-10)
        clarity_score = max(0, min(100, 100 - energy_variance * 100))
    else:
        clarity_score = 70.0
    
    # Pacing (words per minute)
    word_count = len(recognized_text.split())
    pacing = (word_count / duration) * 60 if duration > 0 else 0
    pacing_score = pacing / 15  # Normalize to ~3 syllables/sec
    
    # Breath control (based on audio amplitude patterns)
    breath_score = min(100, clarity_score + 10)
    
    # Nasality estimation (simplified - would need spectral analysis for real)
    nasality_score = max(0, 50 - clarity_score / 3)
    
    # Calculate phoneme errors by comparing target vs recognized
    phoneme_errors = []
    if target_text:
        target_words = target_text.lower().split()
        recognized_words = recognized_text.lower().split()
        
        # Find differences
        matcher = difflib.SequenceMatcher(None, target_words, recognized_words)
        for tag, i1, i2, j1, j2 in matcher.get_opcodes():
            if tag == 'replace':
                for idx, (expected, actual) in enumerate(zip(target_words[i1:i2], recognized_words[j1:j2])):
                    # Find which phonemes differ
                    phoneme_errors.append({
                        "phoneme": expected[:2] if len(expected) > 0 else expected,
                        "expected": expected,
                        "actual": actual,
                        "position": i1 + idx,
                        "confidence": 0.8
                    })
            elif tag == 'delete':
                for idx, expected in enumerate(target_words[i1:i2]):
                    phoneme_errors.append({
                        "phoneme": expected[:2],
                        "expected": expected,
                        "actual": "(missing)",
                        "position": i1 + idx,
                        "confidence": 0.9
                    })
            elif tag == 'insert':
                for idx, actual in enumerate(recognized_words[j1:j2]):
                    phoneme_errors.append({
                        "phoneme": actual[:2],
                        "expected": "(none)",
                        "actual": actual,
                        "position": j1 + idx,
                        "confidence": 0.7
                    })
    
    # Calculate overall score
    if target_text:
        # Use similarity ratio when target is provided
        similarity = difflib.SequenceMatcher(None, target_text.lower(), recognized_text.lower()).ratio()
        overall_score = similarity * 100
    else:
        overall_score = (clarity_score * 0.4 + breath_score * 0.3 + (100 - nasality_score) * 0.3)
    
    metrics = {
        "clarityScore": round(clarity_score, 1),
        "nasalityScore": round(nasality_score, 1),
        "pacingScore": round(pacing_score, 2),
        "breathControlScore": round(breath_score, 1),
        "overallScore": round(overall_score, 1)
    }
    
    # Generate suggestions
    suggestions = []
    if clarity_score < 70:
        suggestions.append("Try speaking more slowly and clearly. Enunciate each word.")
    if overall_score < 70 and target_text:
        suggestions.append(f"Practice saying: '{target_text}'")
    if pacing_score < 2:
        suggestions.append("Try to speak a bit faster for natural flow.")
    elif pacing_score > 5:
        suggestions.append("Slow down a little - give each word time.")
    if len(phoneme_errors) > 0:
        problem_sounds = list(set([e['expected'] for e in phoneme_errors[:3] if e['expected'] != "(none)"]))
        if problem_sounds:
            suggestions.append(f"Focus on these words: {', '.join(problem_sounds)}")
    if not suggestions:
        suggestions.append("Great job! Your pronunciation is clear.")
    
    return metrics, phoneme_errors, suggestions


@app.route('/phrase-memory', methods=['GET'])
def get_phrase_memory_endpoint():
    """Get current phrase memory."""
    try:
        pm = get_phrase_memory()
        return jsonify({
            "success": True,
            "user_name": pm.user_name,
            "known_names": pm.known_names,
            "phrase_corrections": pm.phrase_corrections,
            "frequent_phrases": pm.frequent_phrases
        })
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/phrase-memory', methods=['POST'])
def update_phrase_memory():
    """
    Update phrase memory.
    
    Request:
        {
            "action": "set_name" | "add_name" | "add_phrase",
            "heard": "what was heard",
            "correct": "correct version"
        }
    """
    try:
        data = request.get_json()
        action = data.get('action', '')
        
        pm = get_phrase_memory()
        bridge = get_bridge()
        
        if action == 'set_name':
            name = data.get('name', '')
            if name:
                pm.set_user_name(name)
                bridge.phrase_memory = pm
                return jsonify({"success": True, "message": f"Name set to: {name}"})
        
        elif action == 'add_name':
            heard = data.get('heard', '')
            correct = data.get('correct', '')
            if heard and correct:
                pm.add_name(heard, correct)
                bridge.phrase_memory = pm
                return jsonify({"success": True, "message": f"Name learned: {heard} → {correct}"})
        
        elif action == 'add_phrase':
            heard = data.get('heard', '')
            correct = data.get('correct', '')
            if heard and correct:
                pm.add_phrase_correction(heard, correct)
                bridge.phrase_memory = pm
                return jsonify({"success": True, "message": f"Phrase learned: {heard} → {correct}"})
        
        elif action == 'add_pronunciation':
            # Add a pronunciation correction to the normalizer
            heard = data.get('heard', '')
            correct = data.get('correct', '')
            if heard and correct:
                bridge.normalizer.learn_correction(heard, correct)
                return jsonify({"success": True, "message": f"Pronunciation learned: {heard} → {correct}"})
        
        return jsonify({"success": False, "error": "Invalid action or missing data"}), 400
    
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/voice-samples', methods=['GET'])
def get_voice_samples():
    """List available voice samples."""
    try:
        bridge = get_bridge()
        samples = []
        
        raw_dir = PROJECT_ROOT / "data" / "voice_profile_raw"
        clean_dir = PROJECT_ROOT / "data" / "voice_profile_clean"
        
        for dir_path in [raw_dir, clean_dir]:
            if dir_path.exists():
                for f in dir_path.glob("*.wav"):
                    if f.stat().st_size > 1000:
                        samples.append({
                            "name": f.name,
                            "path": str(f),
                            "size_kb": f.stat().st_size / 1024
                        })
        
        current = bridge._get_voice_sample()
        
        return jsonify({
            "success": True,
            "samples": samples,
            "current_sample": current
        })
    
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


# =============================================================================
# AUDIO UTILITIES
# =============================================================================

def audio_to_wav_bytes(audio: np.ndarray, sample_rate: int = 22050) -> bytes:
    """Convert numpy audio array to WAV bytes."""
    buffer = BytesIO()
    
    # Normalize and convert to int16
    audio_normalized = np.clip(audio, -1.0, 1.0)
    audio_int = (audio_normalized * 32767).astype(np.int16)
    
    with wave.open(buffer, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(audio_int.tobytes())
    
    buffer.seek(0)
    return buffer.read()


def decode_audio(audio_bytes: bytes, audio_format: str) -> Optional[np.ndarray]:
    """Decode audio bytes to numpy array."""
    try:
        if audio_format == 'wav':
            return decode_wav(audio_bytes)
        elif audio_format in ['webm', 'ogg', 'mp3']:
            return decode_with_ffmpeg(audio_bytes, audio_format)
        else:
            # Try WAV first, then ffmpeg
            try:
                return decode_wav(audio_bytes)
            except:
                return decode_with_ffmpeg(audio_bytes, audio_format)
    except Exception as e:
        print(f"Error decoding audio: {e}")
        return None


def decode_wav(audio_bytes: bytes) -> np.ndarray:
    """Decode WAV bytes to numpy array."""
    buffer = BytesIO(audio_bytes)
    with wave.open(buffer, 'rb') as wf:
        frames = wf.readframes(wf.getnframes())
        audio = np.frombuffer(frames, dtype=np.int16)
        audio = audio.astype(np.float32) / 32767.0
        
        # Resample to 16kHz if needed
        sample_rate = wf.getframerate()
        if sample_rate != 16000:
            from scipy.signal import resample
            audio = resample(audio, int(len(audio) * 16000 / sample_rate))
        
        return audio


def decode_with_pydub(audio_bytes: bytes, audio_format: str) -> Optional[np.ndarray]:
    """Decode audio using pydub (requires ffmpeg or libav)."""
    try:
        from pydub import AudioSegment
        
        # Write to temp file
        with tempfile.NamedTemporaryFile(suffix=f'.{audio_format}', delete=False) as f:
            f.write(audio_bytes)
            input_path = f.name
        
        try:
            # Load with pydub
            audio_segment = AudioSegment.from_file(input_path, format=audio_format)
            
            # Convert to 16kHz mono
            audio_segment = audio_segment.set_frame_rate(16000).set_channels(1)
            
            # Get raw samples
            samples = np.array(audio_segment.get_array_of_samples())
            audio = samples.astype(np.float32) / 32767.0
            
            os.unlink(input_path)
            return audio
        except Exception as e:
            print(f"pydub decode error: {e}")
            os.unlink(input_path)
            return None
            
    except ImportError:
        print("pydub not installed")
        return None
    except Exception as e:
        print(f"pydub error: {e}")
        return None


def decode_with_scipy(audio_bytes: bytes, audio_format: str) -> Optional[np.ndarray]:
    """Try to decode using scipy.io.wavfile."""
    try:
        from scipy.io import wavfile
        from scipy.signal import resample
        
        # Write to temp file
        with tempfile.NamedTemporaryFile(suffix=f'.{audio_format}', delete=False) as f:
            f.write(audio_bytes)
            input_path = f.name
        
        try:
            sample_rate, audio = wavfile.read(input_path)
            audio = audio.astype(np.float32) / 32767.0
            
            # Handle stereo
            if len(audio.shape) > 1:
                audio = audio.mean(axis=1)
            
            # Resample to 16kHz
            if sample_rate != 16000:
                audio = resample(audio, int(len(audio) * 16000 / sample_rate))
            
            os.unlink(input_path)
            return audio
        except:
            os.unlink(input_path)
            return None
            
    except Exception as e:
        return None


def decode_with_ffmpeg(audio_bytes: bytes, audio_format: str) -> Optional[np.ndarray]:
    """Decode audio using ffmpeg."""
    try:
        import subprocess
        import shutil
        
        # Check common ffmpeg locations on Windows
        ffmpeg_path = shutil.which('ffmpeg')
        if ffmpeg_path is None:
            # Check common installation paths
            common_paths = [
                r'C:\ffmpeg\bin\ffmpeg.exe',
                r'C:\Program Files\ffmpeg\bin\ffmpeg.exe',
                r'C:\Program Files (x86)\ffmpeg\bin\ffmpeg.exe',
                os.path.expanduser(r'~\ffmpeg\bin\ffmpeg.exe'),
                os.path.expanduser(r'~\scoop\apps\ffmpeg\current\bin\ffmpeg.exe'),
            ]
            for path in common_paths:
                if os.path.exists(path):
                    ffmpeg_path = path
                    break
        
        if ffmpeg_path is None:
            print("❌ ffmpeg not found! Trying pydub fallback...")
            return decode_with_pydub(audio_bytes, audio_format)
        
        # Write to temp file
        with tempfile.NamedTemporaryFile(suffix=f'.{audio_format}', delete=False) as f:
            f.write(audio_bytes)
            input_path = f.name
        
        output_path = input_path + '.wav'
        
        # Convert with ffmpeg
        result = subprocess.run([
            ffmpeg_path, '-y', '-i', input_path,
            '-ar', '16000', '-ac', '1', '-f', 'wav',
            output_path
        ], capture_output=True)
        
        if result.returncode != 0:
            print(f"ffmpeg error: {result.stderr.decode()}")
            os.unlink(input_path)
            # Try pydub as fallback
            return decode_with_pydub(audio_bytes, audio_format)
        
        # Read the WAV file
        with open(output_path, 'rb') as f:
            wav_bytes = f.read()
        
        # Clean up
        os.unlink(input_path)
        os.unlink(output_path)
        
        return decode_wav(wav_bytes)
    
    except Exception as e:
        print(f"ffmpeg decode error: {e}")
        return decode_with_pydub(audio_bytes, audio_format)


# =============================================================================
# MAIN
# =============================================================================

def main():
    """Run the server."""
    print("\n" + "="*60)
    print("🌉 DENUEL VOICE BRIDGE - Web API Server")
    print("="*60)
    print("\nEndpoints:")
    print("   POST /process-text     - Process text to speech")
    print("   POST /process-audio    - Process audio recording")
    print("   GET  /phrase-memory    - Get phrase memory")
    print("   POST /phrase-memory    - Update phrase memory")
    print("   GET  /voice-samples    - List voice samples")
    print("   GET  /health           - Health check")
    print("\n" + "="*60)
    print("Server starting on http://localhost:5000")
    print("="*60 + "\n")
    
    # Pre-load models in background (optional)
    # get_bridge()
    
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True, use_reloader=False)


if __name__ == '__main__':
    main()
