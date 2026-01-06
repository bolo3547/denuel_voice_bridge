"""
Denuel Voice Bridge - Hugging Face Spaces App
==============================================
Gradio interface for voice cloning, transcription, and synthesis.

Deploy to Hugging Face Spaces for free GPU access!
"""

import os
import io
import wave
import tempfile
import numpy as np
import gradio as gr

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
        
        # Tab 5: API Info
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


# Launch
if __name__ == "__main__":
    demo.launch()
