"""
Denuel Voice Bridge - Hugging Face Spaces App
==============================================
Gradio interface for voice cloning, transcription, and synthesis.

Deploy to Hugging Face Spaces for free GPU access!
"""

import os
import io
import wave
import json
import base64
import tempfile
import numpy as np
import gradio as gr
import torch

# Accept XTTS license
os.environ["COQUI_TOS_AGREED"] = "1"

# Global models (lazy loaded)
whisper_model = None
tts_model = None

def load_whisper():
    """Load Whisper model."""
    global whisper_model
    if whisper_model is None:
        import whisper
        whisper_model = whisper.load_model("base")
        print("✅ Whisper loaded!")
    return whisper_model

def load_tts():
    """Load XTTS model."""
    global tts_model
    if tts_model is None:
        from TTS.api import TTS
        tts_model = TTS("tts_models/multilingual/multi-dataset/xtts_v2")
        if torch.cuda.is_available():
            tts_model = tts_model.to("cuda")
        print("✅ XTTS loaded!")
    return tts_model

def save_audio_to_wav(audio_array: np.ndarray, sample_rate: int = 22050) -> str:
    """Save numpy audio to temporary WAV file."""
    temp_file = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    audio_int = (audio_array * 32767).astype(np.int16)
    
    with wave.open(temp_file.name, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(audio_int.tobytes())
    
    return temp_file.name

# ============================================================
# Gradio Functions
# ============================================================

def transcribe_audio(audio_input):
    """Transcribe audio to text."""
    if audio_input is None:
        return "Please upload or record audio first."
    
    try:
        model = load_whisper()
        
        # Handle Gradio audio input (sample_rate, audio_array)
        if isinstance(audio_input, tuple):
            sample_rate, audio_array = audio_input
            # Convert to float32 and normalize
            if audio_array.dtype == np.int16:
                audio_array = audio_array.astype(np.float32) / 32767.0
            elif audio_array.dtype == np.int32:
                audio_array = audio_array.astype(np.float32) / 2147483647.0
            
            # Convert stereo to mono if needed
            if len(audio_array.shape) > 1:
                audio_array = audio_array.mean(axis=1)
            
            # Resample to 16kHz for Whisper
            if sample_rate != 16000:
                import scipy.signal
                audio_array = scipy.signal.resample(
                    audio_array, 
                    int(len(audio_array) * 16000 / sample_rate)
                )
        else:
            # File path
            import whisper
            audio_array = whisper.load_audio(audio_input)
        
        result = model.transcribe(audio_array)
        return result["text"].strip()
    
    except Exception as e:
        return f"Error: {str(e)}"

def synthesize_speech(text, voice_audio, language):
    """Synthesize speech from text with optional voice cloning."""
    if not text:
        return None, "Please enter text to synthesize."
    
    try:
        model = load_tts()
        
        # Handle voice sample
        voice_path = None
        if voice_audio is not None:
            if isinstance(voice_audio, tuple):
                sample_rate, audio_array = voice_audio
                if audio_array.dtype == np.int16:
                    audio_array = audio_array.astype(np.float32) / 32767.0
                if len(audio_array.shape) > 1:
                    audio_array = audio_array.mean(axis=1)
                voice_path = save_audio_to_wav(audio_array, sample_rate)
            else:
                voice_path = voice_audio
        
        # Synthesize
        if voice_path:
            wav = model.tts(text=text, speaker_wav=voice_path, language=language)
        else:
            wav = model.tts(text=text, language=language)
        
        audio_array = np.array(wav, dtype=np.float32)
        
        # Return as (sample_rate, audio_array) for Gradio
        return (22050, audio_array), f"✅ Generated {len(audio_array)/22050:.1f}s of audio"
    
    except Exception as e:
        return None, f"Error: {str(e)}"

def clone_voice(input_audio, target_language, emotion):
    """Full voice cloning pipeline: transcribe → synthesize with cloned voice."""
    if input_audio is None:
        return None, "", "Please upload or record audio first."
    
    try:
        # Step 1: Transcribe
        transcription = transcribe_audio(input_audio)
        
        if transcription.startswith("Error"):
            return None, "", transcription
        
        # Step 2: Apply emotion prefix
        emotion_prefixes = {
            "neutral": "",
            "happy": "(cheerfully) ",
            "sad": "(sadly) ",
            "angry": "(angrily) ",
            "calm": "(calmly) ",
            "excited": "(excitedly) ",
        }
        styled_text = emotion_prefixes.get(emotion, "") + transcription
        
        # Step 3: Synthesize with cloned voice
        output_audio, status = synthesize_speech(styled_text, input_audio, target_language)
        
        return output_audio, transcription, status
    
    except Exception as e:
        return None, "", f"Error: {str(e)}"

def compare_voices(audio1, audio2):
    """Compare two voice samples for similarity."""
    if audio1 is None or audio2 is None:
        return "Please provide both audio samples."
    
    try:
        # Simple comparison using MFCC correlation
        import librosa
        
        def get_audio_array(audio_input):
            if isinstance(audio_input, tuple):
                sr, arr = audio_input
                if arr.dtype == np.int16:
                    arr = arr.astype(np.float32) / 32767.0
                if len(arr.shape) > 1:
                    arr = arr.mean(axis=1)
                return arr, sr
            return None, None
        
        arr1, sr1 = get_audio_array(audio1)
        arr2, sr2 = get_audio_array(audio2)
        
        if arr1 is None or arr2 is None:
            return "Could not process audio files."
        
        # Extract MFCCs
        mfcc1 = librosa.feature.mfcc(y=arr1, sr=sr1, n_mfcc=13)
        mfcc2 = librosa.feature.mfcc(y=arr2, sr=sr2, n_mfcc=13)
        
        # Compare mean MFCC vectors
        mean1 = np.mean(mfcc1, axis=1)
        mean2 = np.mean(mfcc2, axis=1)
        
        # Cosine similarity
        dot = np.dot(mean1, mean2)
        norm1 = np.linalg.norm(mean1)
        norm2 = np.linalg.norm(mean2)
        
        if norm1 > 0 and norm2 > 0:
            similarity = (dot / (norm1 * norm2) + 1) / 2 * 100
        else:
            similarity = 50
        
        # Grade
        if similarity >= 85:
            grade = "A+ (Excellent match!)"
        elif similarity >= 75:
            grade = "A (Very similar)"
        elif similarity >= 65:
            grade = "B (Good match)"
        elif similarity >= 55:
            grade = "C (Moderate)"
        else:
            grade = "D (Low similarity)"
        
        return f"🎯 Similarity: {similarity:.1f}%\n📊 Grade: {grade}"
    
    except Exception as e:
        return f"Error: {str(e)}"


def analyze_pronunciation(audio_input, target_text):
    """
    Analyze pronunciation and provide feedback.
    Compare what was said vs what should have been said.
    """
    if audio_input is None:
        return "Please upload or record audio first.", "", ""
    
    try:
        import difflib
        
        # Transcribe what was actually said
        recognized_text = transcribe_audio(audio_input)
        
        if recognized_text.startswith("Error"):
            return recognized_text, "", ""
        
        # Get audio array for analysis
        if isinstance(audio_input, tuple):
            sample_rate, audio_array = audio_input
            if audio_array.dtype == np.int16:
                audio_array = audio_array.astype(np.float32) / 32767.0
            if len(audio_array.shape) > 1:
                audio_array = audio_array.mean(axis=1)
        else:
            import whisper
            audio_array = whisper.load_audio(audio_input)
            sample_rate = 16000
        
        duration = len(audio_array) / sample_rate
        
        # Calculate metrics
        energy = np.abs(audio_array).mean()
        
        # Clarity score based on energy consistency
        if len(audio_array) > sample_rate:
            chunk_size = sample_rate // 4
            chunks = [audio_array[i:i+chunk_size] for i in range(0, len(audio_array)-chunk_size, chunk_size)]
            chunk_energies = [np.abs(c).mean() for c in chunks]
            energy_variance = np.std(chunk_energies) / (np.mean(chunk_energies) + 1e-10)
            clarity_score = max(0, min(100, 100 - energy_variance * 100))
        else:
            clarity_score = 70.0
        
        # Pacing
        word_count = len(recognized_text.split())
        words_per_min = (word_count / duration) * 60 if duration > 0 else 0
        
        # Compare with target if provided
        phoneme_errors = []
        overall_score = clarity_score
        
        if target_text and target_text.strip():
            target_words = target_text.lower().strip().split()
            recognized_words = recognized_text.lower().strip().split()
            
            # Calculate similarity
            similarity = difflib.SequenceMatcher(None, target_text.lower(), recognized_text.lower()).ratio()
            overall_score = similarity * 100
            
            # Find word differences
            matcher = difflib.SequenceMatcher(None, target_words, recognized_words)
            for tag, i1, i2, j1, j2 in matcher.get_opcodes():
                if tag == 'replace':
                    for expected, actual in zip(target_words[i1:i2], recognized_words[j1:j2]):
                        phoneme_errors.append(f"'{expected}' → '{actual}'")
                elif tag == 'delete':
                    for expected in target_words[i1:i2]:
                        phoneme_errors.append(f"'{expected}' (missing)")
                elif tag == 'insert':
                    for actual in recognized_words[j1:j2]:
                        phoneme_errors.append(f"(extra) '{actual}'")
        
        # Build results
        metrics_text = f"""## 📊 Speech Analysis

| Metric | Score |
|--------|-------|
| **Clarity** | {clarity_score:.0f}/100 |
| **Overall** | {overall_score:.0f}/100 |
| **Pace** | {words_per_min:.0f} words/min |
| **Duration** | {duration:.1f}s |
"""
        
        # Errors
        if phoneme_errors:
            errors_text = "## ⚠️ Pronunciation Errors\n\n"
            for err in phoneme_errors[:5]:
                errors_text += f"- {err}\n"
        else:
            if target_text:
                errors_text = "## ✅ Perfect!\n\nYour pronunciation matched the target text."
            else:
                errors_text = "## 💡 Tip\n\nEnter target text to compare your pronunciation."
        
        # Suggestions
        suggestions = []
        if clarity_score < 70:
            suggestions.append("Try speaking more slowly and clearly")
        if overall_score < 70 and target_text:
            suggestions.append(f"Practice: '{target_text}'")
        if words_per_min > 180:
            suggestions.append("Slow down a bit for clearer speech")
        elif words_per_min < 80 and duration > 2:
            suggestions.append("Try speaking a bit faster for natural flow")
        if len(phoneme_errors) > 0:
            suggestions.append("Focus on the words highlighted as errors")
        if not suggestions:
            suggestions.append("Great job! Keep practicing!")
        
        suggestions_text = "## 💡 Suggestions\n\n" + "\n".join([f"- {s}" for s in suggestions])
        
        return f"**You said:** {recognized_text}", metrics_text + "\n" + errors_text, suggestions_text
    
    except Exception as e:
        return f"Error: {str(e)}", "", ""


# ============================================================
# Gradio Interface
# ============================================================

# Check for GPU
import torch
device_info = "🚀 GPU: " + torch.cuda.get_device_name(0) if torch.cuda.is_available() else "💻 CPU Mode"

# Supported languages
LANGUAGES = {
    "English": "en",
    "Spanish": "es", 
    "French": "fr",
    "German": "de",
    "Italian": "it",
    "Portuguese": "pt",
    "Polish": "pl",
    "Turkish": "tr",
    "Russian": "ru",
    "Dutch": "nl",
    "Czech": "cs",
    "Arabic": "ar",
    "Chinese": "zh",
    "Japanese": "ja",
    "Korean": "ko",
    "Hindi": "hi"
}

EMOTIONS = ["neutral", "happy", "sad", "angry", "calm", "excited"]

# Custom CSS
css = """
.gradio-container {
    font-family: 'Segoe UI', sans-serif;
}
.title {
    text-align: center;
    margin-bottom: 1rem;
}
"""

# Build interface
with gr.Blocks(css=css, title="Denuel Voice Bridge") as demo:
    gr.Markdown(
        """
        # 🎙️ Denuel Voice Bridge
        ### Voice Cloning & Synthesis powered by Whisper + XTTS
        
        Clone your voice, transcribe speech, and synthesize in multiple languages!
        """
    )
    gr.Markdown(f"**Device:** {device_info}")
    
    with gr.Tabs():
        # Tab 1: Voice Cloning
        with gr.TabItem("🎭 Voice Clone"):
            gr.Markdown("Record or upload your voice, and hear it cloned!")
            
            with gr.Row():
                with gr.Column():
                    clone_input = gr.Audio(
                        label="🎤 Input Audio (Record or Upload)",
                        type="numpy",
                        sources=["microphone", "upload"]
                    )
                    clone_language = gr.Dropdown(
                        choices=list(LANGUAGES.keys()),
                        value="English",
                        label="🌍 Output Language"
                    )
                    clone_emotion = gr.Dropdown(
                        choices=EMOTIONS,
                        value="neutral",
                        label="🎭 Emotion Style"
                    )
                    clone_btn = gr.Button("🔄 Clone Voice", variant="primary")
                
                with gr.Column():
                    clone_output = gr.Audio(label="🔊 Cloned Output", type="numpy")
                    clone_text = gr.Textbox(label="📝 Transcription", lines=3)
                    clone_status = gr.Textbox(label="Status")
            
            clone_btn.click(
                fn=lambda audio, lang, emo: clone_voice(audio, LANGUAGES[lang], emo),
                inputs=[clone_input, clone_language, clone_emotion],
                outputs=[clone_output, clone_text, clone_status]
            )
        
        # Tab 2: Transcription
        with gr.TabItem("📝 Transcribe"):
            gr.Markdown("Convert speech to text using Whisper.")
            
            with gr.Row():
                with gr.Column():
                    transcribe_input = gr.Audio(
                        label="🎤 Audio Input",
                        type="numpy",
                        sources=["microphone", "upload"]
                    )
                    transcribe_btn = gr.Button("📝 Transcribe", variant="primary")
                
                with gr.Column():
                    transcribe_output = gr.Textbox(
                        label="📜 Transcription",
                        lines=5
                    )
            
            transcribe_btn.click(
                fn=transcribe_audio,
                inputs=[transcribe_input],
                outputs=[transcribe_output]
            )
        
        # Tab 3: Text-to-Speech
        with gr.TabItem("🔊 Synthesize"):
            gr.Markdown("Convert text to speech with optional voice cloning.")
            
            with gr.Row():
                with gr.Column():
                    synth_text = gr.Textbox(
                        label="📝 Text to Speak",
                        lines=3,
                        placeholder="Enter the text you want to synthesize..."
                    )
                    synth_voice = gr.Audio(
                        label="🎤 Voice Sample (optional, for cloning)",
                        type="numpy",
                        sources=["microphone", "upload"]
                    )
                    synth_language = gr.Dropdown(
                        choices=list(LANGUAGES.keys()),
                        value="English",
                        label="🌍 Language"
                    )
                    synth_btn = gr.Button("🔊 Synthesize", variant="primary")
                
                with gr.Column():
                    synth_output = gr.Audio(label="🔊 Generated Speech", type="numpy")
                    synth_status = gr.Textbox(label="Status")
            
            synth_btn.click(
                fn=lambda text, voice, lang: synthesize_speech(text, voice, LANGUAGES[lang]),
                inputs=[synth_text, synth_voice, synth_language],
                outputs=[synth_output, synth_status]
            )
        
        # Tab 4: Voice Comparison
        with gr.TabItem("📊 Compare"):
            gr.Markdown("Compare two voice samples to see how similar they are.")
            
            with gr.Row():
                compare_audio1 = gr.Audio(
                    label="🎤 Voice Sample 1",
                    type="numpy",
                    sources=["microphone", "upload"]
                )
                compare_audio2 = gr.Audio(
                    label="🎤 Voice Sample 2",
                    type="numpy",
                    sources=["microphone", "upload"]
                )
            
            compare_btn = gr.Button("📊 Compare Voices", variant="primary")
            compare_result = gr.Textbox(label="Similarity Result", lines=3)
            
            compare_btn.click(
                fn=compare_voices,
                inputs=[compare_audio1, compare_audio2],
                outputs=[compare_result]
            )
        
        # Tab 5: Pronunciation Practice
        with gr.TabItem("🗣️ Pronunciation"):
            gr.Markdown(
                """
                ## Practice Your Pronunciation
                
                1. **Enter the target sentence** you want to practice
                2. **Record yourself** saying it
                3. **Get feedback** on your pronunciation
                """
            )
            
            with gr.Row():
                with gr.Column():
                    pron_target = gr.Textbox(
                        label="📝 Target Text (what you want to say)",
                        lines=2,
                        placeholder="The quick brown fox jumps over the lazy dog."
                    )
                    pron_audio = gr.Audio(
                        label="🎤 Record Yourself",
                        type="numpy",
                        sources=["microphone", "upload"]
                    )
                    pron_btn = gr.Button("🔍 Analyze Pronunciation", variant="primary")
                
                with gr.Column():
                    pron_recognized = gr.Markdown(label="What you said")
                    pron_metrics = gr.Markdown(label="Analysis")
                    pron_suggestions = gr.Markdown(label="Suggestions")
            
            # Practice prompts
            gr.Markdown("### 📋 Practice Prompts (click to use)")
            with gr.Row():
                prompt1 = gr.Button("The quick brown fox", size="sm")
                prompt2 = gr.Button("She sells seashells", size="sm")
                prompt3 = gr.Button("Peter Piper picked", size="sm")
            
            prompt1.click(lambda: "The quick brown fox jumps over the lazy dog.", outputs=[pron_target])
            prompt2.click(lambda: "She sells seashells by the seashore.", outputs=[pron_target])
            prompt3.click(lambda: "Peter Piper picked a peck of pickled peppers.", outputs=[pron_target])
            
            pron_btn.click(
                fn=analyze_pronunciation,
                inputs=[pron_audio, pron_target],
                outputs=[pron_recognized, pron_metrics, pron_suggestions]
            )
        
        # Tab 6: API Info
        with gr.TabItem("🔌 API"):
            gr.Markdown(
                """
                ## API Usage
                
                This Space also provides an API! Use it in your apps:
                
                ### Python Example
                ```python
                from gradio_client import Client
                
                client = Client("YOUR_SPACE_NAME")
                
                # Transcribe
                result = client.predict(
                    audio_file,  # filepath
                    api_name="/transcribe_audio"
                )
                
                # Synthesize
                result = client.predict(
                    "Hello world!",  # text
                    None,  # voice sample (optional)
                    "English",  # language
                    api_name="/synthesize_speech"
                )
                ```
                
                ### Flutter/Dart Example
                ```dart
                import 'package:http/http.dart' as http;
                
                final response = await http.post(
                  Uri.parse('https://YOUR_SPACE.hf.space/api/predict'),
                  body: jsonEncode({
                    'data': [audioBase64, 'English', 'neutral']
                  }),
                );
                ```
                
                📖 See the API docs at the bottom of this page!
                """
            )
    
    gr.Markdown(
        """
        ---
        ### 🔗 Links
        - [GitHub Repository](https://github.com/YOUR_USERNAME/denuel_voice_bridge)
        - Built with ❤️ using [Whisper](https://github.com/openai/whisper) & [XTTS](https://github.com/coqui-ai/TTS)
        
        ⚠️ **Note:** Voice cloning should only be used ethically and with consent.
        """
    )


# ============================================================
# REST API Endpoints for Flutter App
# ============================================================

def process_audio_api(audio_base64: str, format: str = "wav") -> dict:
    """
    Process audio through the voice bridge pipeline.
    Returns transcription and enhanced/processed audio.
    """
    try:
        # Decode base64 audio
        audio_bytes = base64.b64decode(audio_base64)
        
        # Save to temp file
        suffix = f".{format}" if format else ".wav"
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as f:
            f.write(audio_bytes)
            temp_path = f.name
        
        # Load audio with librosa
        import librosa
        import scipy.signal
        
        audio_array, sr = librosa.load(temp_path, sr=16000)
        
        # Transcribe
        model = load_whisper()
        result = model.transcribe(audio_array)
        transcription = result["text"].strip()
        
        # Apply noise reduction
        try:
            import noisereduce as nr
            enhanced_audio = nr.reduce_noise(y=audio_array, sr=sr)
        except:
            enhanced_audio = audio_array
        
        # Convert to wav bytes for response
        enhanced_int = (enhanced_audio * 32767).astype(np.int16)
        wav_buffer = io.BytesIO()
        with wave.open(wav_buffer, 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sr)
            wf.writeframes(enhanced_int.tobytes())
        
        enhanced_base64 = base64.b64encode(wav_buffer.getvalue()).decode('utf-8')
        
        # Cleanup
        os.unlink(temp_path)
        
        return {
            "success": True,
            "transcription": transcription,
            "audio_base64": enhanced_base64,
            "format": "wav",
            "sample_rate": sr,
            "duration": len(enhanced_audio) / sr
        }
        
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }


def synthesize_api(text: str, language: str = "en", voice_base64: str = None) -> dict:
    """
    Synthesize text to speech with optional voice cloning.
    """
    try:
        model = load_tts()
        
        # Language mapping
        lang_map = {
            "en": "en", "es": "es", "fr": "fr", "de": "de",
            "it": "it", "pt": "pt", "pl": "pl", "tr": "tr",
            "ru": "ru", "nl": "nl", "cs": "cs", "ar": "ar",
            "zh": "zh-cn", "ja": "ja", "ko": "ko", "hi": "hi"
        }
        lang_code = lang_map.get(language, "en")
        
        voice_path = None
        if voice_base64:
            # Decode voice sample
            voice_bytes = base64.b64decode(voice_base64)
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
                f.write(voice_bytes)
                voice_path = f.name
        
        # Synthesize
        if voice_path:
            wav = model.tts(text=text, speaker_wav=voice_path, language=lang_code)
            os.unlink(voice_path)
        else:
            wav = model.tts(text=text, language=lang_code)
        
        audio_array = np.array(wav, dtype=np.float32)
        
        # Convert to wav bytes
        audio_int = (audio_array * 32767).astype(np.int16)
        wav_buffer = io.BytesIO()
        with wave.open(wav_buffer, 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(22050)
            wf.writeframes(audio_int.tobytes())
        
        audio_base64 = base64.b64encode(wav_buffer.getvalue()).decode('utf-8')
        
        return {
            "success": True,
            "audio_base64": audio_base64,
            "format": "wav",
            "sample_rate": 22050,
            "duration": len(audio_array) / 22050
        }
        
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }


# Create API interface for Gradio
with gr.Blocks() as api_interface:
    # Hidden API endpoints
    gr.Interface(
        fn=process_audio_api,
        inputs=[
            gr.Textbox(label="audio_base64"),
            gr.Textbox(label="format", value="wav")
        ],
        outputs=gr.JSON(),
        api_name="process_audio"
    )
    
    gr.Interface(
        fn=synthesize_api,
        inputs=[
            gr.Textbox(label="text"),
            gr.Textbox(label="language", value="en"),
            gr.Textbox(label="voice_base64", value="")
        ],
        outputs=gr.JSON(),
        api_name="synthesize"
    )


# Launch
if __name__ == "__main__":
    demo.launch()
