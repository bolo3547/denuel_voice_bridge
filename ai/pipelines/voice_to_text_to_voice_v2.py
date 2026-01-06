"""
Voice-to-Text-to-Voice Pipeline (Enhanced)
==========================================
Full-featured voice cloning pipeline with:
- Multi-language support
- Emotion/style transfer
- Audio enhancement
- Voice analysis
- Profile management
- Real-time streaming mode

Usage:
    python ai/pipelines/voice_to_text_to_voice_v2.py --interactive

Flow:
    🎤 Record → 🎛️ Enhance → 📝 Transcribe → 🎭 Style → 🔊 Synthesize → 📊 Analyze
"""

import os
import sys
import tempfile
import wave
import threading
import queue
from pathlib import Path
from typing import Optional, Tuple, Callable
from dataclasses import dataclass

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

import numpy as np

try:
    import torch
    import sounddevice as sd
except ImportError as e:
    print(f"Missing dependency: {e}")
    print("Install with: pip install torch sounddevice")
    sys.exit(1)

# Import our enhanced modules
try:
    from ai.utils.audio_enhancer import AudioEnhancer
    from ai.utils.voice_analyzer import VoiceAnalyzer, VoiceAnalysis
    from ai.utils.voice_profile_manager import VoiceProfileManager
except ImportError:
    # Fallback if running standalone
    AudioEnhancer = None
    VoiceAnalyzer = None
    VoiceProfileManager = None

# Configuration
SAMPLE_RATE = 22050
CHANNELS = 1
RECORDING_SECONDS = 5

# Paths
OUTPUT_DIR = PROJECT_ROOT / "data" / "outputs"

# Supported languages for XTTS v2
SUPPORTED_LANGUAGES = {
    "en": "English", "es": "Spanish", "fr": "French", "de": "German",
    "it": "Italian", "pt": "Portuguese", "pl": "Polish", "tr": "Turkish",
    "ru": "Russian", "nl": "Dutch", "cs": "Czech", "ar": "Arabic",
    "zh": "Chinese", "ja": "Japanese", "ko": "Korean", "hi": "Hindi"
}

# Emotion styles
EMOTION_STYLES = {
    "neutral": "",
    "happy": "(cheerfully) ",
    "sad": "(sadly) ",
    "angry": "(angrily) ",
    "excited": "(excitedly) ",
    "calm": "(calmly) ",
    "whisper": "(whispering) ",
    "loud": "(loudly) ",
}


@dataclass
class PipelineResult:
    """Container for pipeline results."""
    input_audio: np.ndarray
    enhanced_audio: Optional[np.ndarray]
    text: str
    output_text: str
    output_audio: np.ndarray
    input_analysis: Optional[VoiceAnalysis]
    output_analysis: Optional[VoiceAnalysis]
    similarity_score: Optional[float]
    
    def summary(self) -> dict:
        return {
            "text": self.text,
            "output_text": self.output_text,
            "input_duration": len(self.input_audio) / SAMPLE_RATE,
            "output_duration": len(self.output_audio) / SAMPLE_RATE if self.output_audio is not None else 0,
            "similarity": self.similarity_score
        }


class VoiceToTextToVoiceV2:
    """Enhanced Voice → Text → Voice Pipeline"""
    
    def __init__(self, voice_sample_path: str = None):
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        print(f"🖥️  Using device: {self.device}")
        
        # Models (lazy loaded)
        self.whisper_model = None
        self.tts_model = None
        
        # Enhanced modules
        self.enhancer = AudioEnhancer() if AudioEnhancer else None
        self.analyzer = VoiceAnalyzer() if VoiceAnalyzer else None
        self.profile_manager = VoiceProfileManager() if VoiceProfileManager else None
        
        # Settings
        self.voice_sample_path = voice_sample_path
        self.recording_duration = RECORDING_SECONDS
        self.auto_save = False
        self.source_language = "en"
        self.target_language = "en"
        self.emotion = "neutral"
        self.speed = 1.0
        self.enhance_input = True
        self.analyze_output = True
        
        # State
        self.last_result: Optional[PipelineResult] = None
        self.is_streaming = False
        self._stream_callback = None
        
        # Ensure output directory
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    # ================================================================
    # Model Loading
    # ================================================================
    
    def load_whisper(self, model_size: str = "base"):
        """Load Whisper model for speech-to-text."""
        if self.whisper_model is not None:
            return
        
        print(f"📥 Loading Whisper ({model_size})...")
        try:
            import whisper
            self.whisper_model = whisper.load_model(model_size, device=self.device)
            print("✅ Whisper loaded!")
        except ImportError:
            print("❌ Whisper not installed. Run: pip install openai-whisper")
            raise
    
    def load_tts(self):
        """Load XTTS model for text-to-speech."""
        if self.tts_model is not None:
            return
        
        print("📥 Loading XTTS v2 (this may take a moment)...")
        try:
            os.environ["COQUI_TOS_AGREED"] = "1"
            from TTS.api import TTS
            self.tts_model = TTS("tts_models/multilingual/multi-dataset/xtts_v2").to(self.device)
            print("✅ XTTS loaded!")
        except ImportError:
            print("❌ TTS not installed. Run: pip install coqui-tts")
            raise
    
    # ================================================================
    # Audio Recording
    # ================================================================
    
    def record_audio(self, duration: float = None) -> np.ndarray:
        """Record audio from microphone."""
        duration = duration or self.recording_duration
        print(f"🎤 Recording for {duration} seconds...")
        print("   Speak now!")
        
        audio = sd.rec(
            int(duration * SAMPLE_RATE),
            samplerate=SAMPLE_RATE,
            channels=CHANNELS,
            dtype='float32'
        )
        sd.wait()
        
        print("✅ Recording complete!")
        return audio.flatten()
    
    def record_until_silence(self, max_duration: float = 30.0,
                             silence_threshold: float = 0.01,
                             silence_duration: float = 1.5) -> np.ndarray:
        """Record until silence is detected."""
        print("🎤 Recording (will stop after silence)...")
        print("   Speak now!")
        
        audio_chunks = []
        silence_samples = 0
        max_samples = int(max_duration * SAMPLE_RATE)
        silence_samples_threshold = int(silence_duration * SAMPLE_RATE)
        chunk_size = int(0.1 * SAMPLE_RATE)  # 100ms chunks
        
        def callback(indata, frames, time, status):
            nonlocal silence_samples
            audio_chunks.append(indata.copy())
            
            # Check for silence
            if np.max(np.abs(indata)) < silence_threshold:
                silence_samples += frames
            else:
                silence_samples = 0
        
        with sd.InputStream(samplerate=SAMPLE_RATE, channels=CHANNELS,
                           dtype='float32', callback=callback,
                           blocksize=chunk_size):
            while silence_samples < silence_samples_threshold:
                if sum(len(c) for c in audio_chunks) > max_samples:
                    break
                sd.sleep(100)
        
        print("✅ Recording complete!")
        return np.concatenate(audio_chunks).flatten()
    
    # ================================================================
    # Audio Enhancement
    # ================================================================
    
    def enhance_audio(self, audio: np.ndarray) -> np.ndarray:
        """Enhance audio quality."""
        if self.enhancer is None:
            return audio
        
        print("🎛️  Enhancing audio...")
        enhanced = self.enhancer.full_enhance(audio)
        print("✅ Enhancement complete!")
        return enhanced
    
    # ================================================================
    # Transcription
    # ================================================================
    
    def transcribe(self, audio: np.ndarray) -> str:
        """Transcribe audio to text using Whisper."""
        self.load_whisper()
        
        print("📝 Transcribing...")
        
        # Whisper expects float32 audio
        if audio.dtype != np.float32:
            audio = audio.astype(np.float32)
        
        # Resample to 16kHz for Whisper
        if SAMPLE_RATE != 16000:
            import scipy.signal
            audio = scipy.signal.resample(audio, int(len(audio) * 16000 / SAMPLE_RATE))
        
        result = self.whisper_model.transcribe(
            audio,
            fp16=(self.device == "cuda"),
            language=self.source_language if self.source_language != "auto" else None
        )
        
        text = result["text"].strip()
        detected_lang = result.get("language", self.source_language)
        
        print(f"📜 Transcribed ({detected_lang}): \"{text}\"")
        return text
    
    # ================================================================
    # Text Processing (Emotion, Style, Translation)
    # ================================================================
    
    def apply_emotion(self, text: str, emotion: str = None) -> str:
        """Apply emotion markers to text."""
        emotion = emotion or self.emotion
        prefix = EMOTION_STYLES.get(emotion, "")
        return prefix + text
    
    def translate_text(self, text: str, source_lang: str, target_lang: str) -> str:
        """
        Translate text between languages.
        Note: For production, integrate with a translation API.
        """
        if source_lang == target_lang:
            return text
        
        # Placeholder - integrate with actual translation API
        print(f"🌐 Translation: {source_lang} → {target_lang}")
        print("   (Using placeholder - integrate translation API for real usage)")
        return text
    
    # ================================================================
    # Speech Synthesis
    # ================================================================
    
    def synthesize(self, text: str, voice_sample: str = None,
                   language: str = None) -> np.ndarray:
        """Synthesize text to speech with voice cloning."""
        self.load_tts()
        
        if not text:
            print("⚠️  No text to synthesize!")
            return None
        
        language = language or self.target_language
        print(f"🔊 Synthesizing ({language})...")
        
        # Get voice sample
        voice_sample = voice_sample or self._get_voice_sample()
        
        if voice_sample:
            print(f"   Using voice: {Path(voice_sample).name}")
            wav = self.tts_model.tts(
                text=text,
                speaker_wav=voice_sample,
                language=language
            )
        else:
            print("   ⚠️  No voice sample, using default")
            wav = self.tts_model.tts(text=text, language=language)
        
        audio = np.array(wav, dtype=np.float32)
        
        # Apply speed adjustment
        if self.speed != 1.0:
            audio = self._adjust_speed(audio, self.speed)
        
        print("✅ Synthesis complete!")
        return audio
    
    def _adjust_speed(self, audio: np.ndarray, speed: float) -> np.ndarray:
        """Adjust audio speed without changing pitch."""
        try:
            from scipy import signal
            new_length = int(len(audio) / speed)
            return signal.resample(audio, new_length).astype(np.float32)
        except ImportError:
            indices = np.linspace(0, len(audio) - 1, int(len(audio) / speed))
            return np.interp(indices, np.arange(len(audio)), audio).astype(np.float32)
    
    def _get_voice_sample(self) -> Optional[str]:
        """Get voice sample for cloning."""
        # Check explicit path
        if self.voice_sample_path and Path(self.voice_sample_path).exists():
            return str(self.voice_sample_path)
        
        # Check profile manager
        if self.profile_manager:
            profiles = self.profile_manager.list_profiles()
            if profiles:
                sample = self.profile_manager.get_best_sample(profiles[0].id)
                if sample:
                    return sample
        
        # Check raw samples directory
        raw_dir = PROJECT_ROOT / "data" / "voice_profile_raw"
        if raw_dir.exists():
            samples = [f for f in raw_dir.glob("*.wav") if f.stat().st_size > 1000]
            if samples:
                samples.sort(key=lambda x: x.stat().st_mtime, reverse=True)
                return str(samples[0])
        
        # Check clean samples
        clean_dir = PROJECT_ROOT / "data" / "voice_profile_clean"
        if clean_dir.exists():
            samples = [f for f in clean_dir.glob("*.wav") if f.stat().st_size > 1000]
            if samples:
                return str(samples[0])
        
        return None
    
    # ================================================================
    # Voice Analysis
    # ================================================================
    
    def analyze_voice(self, audio: np.ndarray, text: str = None) -> Optional[VoiceAnalysis]:
        """Analyze voice characteristics."""
        if self.analyzer is None:
            return None
        
        return self.analyzer.analyze(audio, text)
    
    def compare_voices(self, audio1: np.ndarray, audio2: np.ndarray) -> float:
        """Compare two voice samples for similarity."""
        if self.analyzer is None:
            return 0.0
        
        result = self.analyzer.compare_voices(audio1, audio2)
        return result.similarity_score
    
    # ================================================================
    # Full Pipeline
    # ================================================================
    
    def run_pipeline(self, audio: np.ndarray = None, 
                     duration: float = None) -> PipelineResult:
        """
        Run the full enhanced pipeline.
        
        Flow: Record → Enhance → Transcribe → Style → Synthesize → Analyze
        """
        print("\n" + "="*60)
        print("🎙️  Enhanced Voice-to-Text-to-Voice Pipeline")
        print("="*60 + "\n")
        
        # Step 1: Record or use provided audio
        if audio is None:
            audio = self.record_audio(duration or self.recording_duration)
        input_audio = audio
        
        # Step 2: Enhance input
        enhanced_audio = None
        if self.enhance_input and self.enhancer:
            enhanced_audio = self.enhance_audio(audio)
            audio = enhanced_audio
        
        # Step 3: Analyze input
        input_analysis = None
        if self.analyze_output and self.analyzer:
            print("📊 Analyzing input voice...")
            input_analysis = self.analyze_voice(audio)
        
        # Step 4: Transcribe
        text = self.transcribe(audio)
        
        if not text:
            print("❌ No speech detected!")
            return None
        
        # Step 5: Apply emotion/style
        output_text = self.apply_emotion(text, self.emotion)
        
        # Step 6: Translate if needed
        if self.target_language != self.source_language:
            output_text = self.translate_text(output_text, 
                                              self.source_language, 
                                              self.target_language)
        
        # Step 7: Synthesize
        output_audio = self.synthesize(output_text)
        
        if output_audio is None:
            print("❌ Synthesis failed!")
            return None
        
        # Step 8: Analyze output
        output_analysis = None
        similarity = None
        if self.analyze_output and self.analyzer:
            print("📊 Analyzing output voice...")
            output_analysis = self.analyze_voice(output_audio, output_text)
            
            # Compare input and output
            similarity = self.compare_voices(audio, output_audio)
            print(f"   Voice similarity: {similarity*100:.1f}%")
        
        # Create result
        result = PipelineResult(
            input_audio=input_audio,
            enhanced_audio=enhanced_audio,
            text=text,
            output_text=output_text,
            output_audio=output_audio,
            input_analysis=input_analysis,
            output_analysis=output_analysis,
            similarity_score=similarity
        )
        
        self.last_result = result
        
        # Step 9: Play result
        print("\n▶️  Playing synthesized voice...")
        self.play_audio(output_audio)
        
        # Step 10: Auto-save if enabled
        if self.auto_save:
            self.save_last_output()
        
        print("\n✅ Pipeline complete!")
        return result
    
    # ================================================================
    # Streaming Mode
    # ================================================================
    
    def start_streaming(self, callback: Callable[[str, np.ndarray], None]):
        """
        Start streaming mode for real-time voice conversion.
        
        Args:
            callback: Function called with (text, audio) for each chunk
        """
        self.is_streaming = True
        self._stream_callback = callback
        
        print("🎙️  Streaming mode started (press Ctrl+C to stop)")
        
        audio_queue = queue.Queue()
        
        def audio_callback(indata, frames, time, status):
            if self.is_streaming:
                audio_queue.put(indata.copy())
        
        def process_thread():
            buffer = []
            buffer_duration = 0
            target_duration = 3.0  # Process every 3 seconds
            
            while self.is_streaming:
                try:
                    chunk = audio_queue.get(timeout=0.5)
                    buffer.append(chunk)
                    buffer_duration += len(chunk) / SAMPLE_RATE
                    
                    if buffer_duration >= target_duration:
                        audio = np.concatenate(buffer).flatten()
                        
                        # Process
                        text = self.transcribe(audio)
                        if text:
                            output = self.synthesize(text)
                            if output is not None and self._stream_callback:
                                self._stream_callback(text, output)
                        
                        buffer = []
                        buffer_duration = 0
                
                except queue.Empty:
                    continue
        
        # Start processing thread
        processor = threading.Thread(target=process_thread, daemon=True)
        processor.start()
        
        # Start audio input stream
        with sd.InputStream(samplerate=SAMPLE_RATE, channels=CHANNELS,
                           dtype='float32', callback=audio_callback):
            try:
                while self.is_streaming:
                    sd.sleep(100)
            except KeyboardInterrupt:
                pass
        
        self.stop_streaming()
    
    def stop_streaming(self):
        """Stop streaming mode."""
        self.is_streaming = False
        self._stream_callback = None
        print("🛑 Streaming stopped")
    
    # ================================================================
    # Playback & Saving
    # ================================================================
    
    def play_audio(self, audio: np.ndarray, sample_rate: int = 22050):
        """Play audio through speakers."""
        print("🔊 Playing...")
        sd.play(audio, sample_rate)
        sd.wait()
        print("✅ Playback complete!")
    
    def save_audio(self, audio: np.ndarray, filename: str = None,
                   sample_rate: int = 22050) -> str:
        """Save audio to WAV file."""
        import datetime
        
        if not filename:
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"clone_{timestamp}.wav"
        
        filepath = OUTPUT_DIR / filename
        
        audio_int = (audio * 32767).astype(np.int16)
        with wave.open(str(filepath), 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(audio_int.tobytes())
        
        print(f"💾 Saved to: {filepath}")
        return str(filepath)
    
    def save_last_output(self, filename: str = None) -> Optional[str]:
        """Save the last pipeline output."""
        if self.last_result is None or self.last_result.output_audio is None:
            print("⚠️  No audio to save!")
            return None
        
        return self.save_audio(self.last_result.output_audio, filename)
    
    def replay_last(self):
        """Replay the last output."""
        if self.last_result is None or self.last_result.output_audio is None:
            print("⚠️  No audio to replay!")
            return
        self.play_audio(self.last_result.output_audio)


# ================================================================
# Interactive Mode
# ================================================================

def print_help():
    """Print interactive mode help."""
    print("\n" + "-"*60)
    print("📖 Commands:")
    print("-"*60)
    print("   ENTER    - Record and process")
    print("   t        - Type text to synthesize")
    print("   r        - Replay last output")
    print("   s        - Save last output")
    print("   d <sec>  - Set recording duration")
    print("   l <code> - Set source language (e.g., 'l en')")
    print("   L <code> - Set target language (e.g., 'L es')")
    print("   e <name> - Set emotion (happy, sad, angry, calm, etc.)")
    print("   v        - List/select voice profiles")
    print("   p        - Create new voice profile")
    print("   a        - Toggle analysis display")
    print("   n        - Toggle audio enhancement")
    print("   S        - Toggle auto-save")
    print("   o        - Open outputs folder")
    print("   ?        - Show current settings")
    print("   h        - Show this help")
    print("   q        - Quit")
    print("-"*60 + "\n")


def show_settings(pipeline: VoiceToTextToVoiceV2):
    """Show current pipeline settings."""
    print("\n" + "-"*40)
    print("⚙️  Current Settings:")
    print("-"*40)
    print(f"   Device:          {pipeline.device}")
    print(f"   Duration:        {pipeline.recording_duration}s")
    print(f"   Source lang:     {pipeline.source_language}")
    print(f"   Target lang:     {pipeline.target_language}")
    print(f"   Emotion:         {pipeline.emotion}")
    print(f"   Speed:           {pipeline.speed}x")
    print(f"   Enhancement:     {'ON' if pipeline.enhance_input else 'OFF'}")
    print(f"   Analysis:        {'ON' if pipeline.analyze_output else 'OFF'}")
    print(f"   Auto-save:       {'ON' if pipeline.auto_save else 'OFF'}")
    if pipeline.voice_sample_path:
        print(f"   Voice sample:    {Path(pipeline.voice_sample_path).name}")
    print("-"*40 + "\n")


def interactive_mode():
    """Run in interactive mode."""
    print("\n" + "="*60)
    print("🎙️  Enhanced Voice-to-Text-to-Voice Pipeline")
    print("="*60)
    
    pipeline = VoiceToTextToVoiceV2()
    print_help()
    show_settings(pipeline)
    
    while True:
        try:
            cmd = input(">>> ").strip()
        except EOFError:
            break
        
        cmd_lower = cmd.lower()
        
        if cmd_lower == 'q':
            print("👋 Goodbye!")
            break
        
        elif cmd_lower == 'h':
            print_help()
        
        elif cmd_lower == '?':
            show_settings(pipeline)
        
        elif cmd_lower == 't':
            text = input("Enter text: ").strip()
            if text:
                text = pipeline.apply_emotion(text)
                audio = pipeline.synthesize(text)
                if audio is not None:
                    pipeline.last_result = PipelineResult(
                        input_audio=np.array([]),
                        enhanced_audio=None,
                        text=text,
                        output_text=text,
                        output_audio=audio,
                        input_analysis=None,
                        output_analysis=None,
                        similarity_score=None
                    )
                    pipeline.play_audio(audio)
        
        elif cmd_lower == 'r':
            pipeline.replay_last()
        
        elif cmd_lower == 's':
            pipeline.save_last_output()
        
        elif cmd_lower.startswith('d '):
            try:
                duration = float(cmd.split()[1])
                if 1 <= duration <= 60:
                    pipeline.recording_duration = duration
                    print(f"✅ Duration set to {duration}s")
                else:
                    print("⚠️  Duration must be 1-60 seconds")
            except (ValueError, IndexError):
                print("⚠️  Usage: d <seconds>")
        
        elif cmd_lower.startswith('l '):
            lang = cmd.split()[1].lower()
            if lang in SUPPORTED_LANGUAGES or lang == "auto":
                pipeline.source_language = lang
                print(f"✅ Source language: {SUPPORTED_LANGUAGES.get(lang, lang)}")
            else:
                print(f"⚠️  Unknown language. Supported: {', '.join(SUPPORTED_LANGUAGES.keys())}")
        
        elif cmd.startswith('L '):
            lang = cmd.split()[1].lower()
            if lang in SUPPORTED_LANGUAGES:
                pipeline.target_language = lang
                print(f"✅ Target language: {SUPPORTED_LANGUAGES.get(lang, lang)}")
            else:
                print(f"⚠️  Unknown language. Supported: {', '.join(SUPPORTED_LANGUAGES.keys())}")
        
        elif cmd_lower.startswith('e '):
            emotion = cmd.split()[1].lower()
            if emotion in EMOTION_STYLES:
                pipeline.emotion = emotion
                print(f"✅ Emotion set to: {emotion}")
            else:
                print(f"⚠️  Unknown emotion. Available: {', '.join(EMOTION_STYLES.keys())}")
        
        elif cmd_lower == 'v':
            if pipeline.profile_manager:
                pipeline.profile_manager.print_profiles()
                profiles = pipeline.profile_manager.list_profiles()
                if profiles:
                    choice = input("Select profile # (or ENTER to skip): ").strip()
                    if choice.isdigit() and 1 <= int(choice) <= len(profiles):
                        profile = profiles[int(choice)-1]
                        sample = pipeline.profile_manager.get_best_sample(profile.id)
                        if sample:
                            pipeline.voice_sample_path = sample
                            print(f"✅ Using profile: {profile.name}")
            else:
                print("⚠️  Profile manager not available")
        
        elif cmd_lower == 'p':
            if pipeline.profile_manager:
                name = input("Profile name: ").strip()
                if name:
                    profile = pipeline.profile_manager.create_profile(name)
                    print(f"✅ Created profile: {profile.name} (ID: {profile.id})")
                    
                    # Record sample
                    if input("Record a sample now? (y/n): ").lower() == 'y':
                        audio = pipeline.record_audio(10)
                        pipeline.profile_manager.add_sample(profile.id, audio)
            else:
                print("⚠️  Profile manager not available")
        
        elif cmd_lower == 'a':
            pipeline.analyze_output = not pipeline.analyze_output
            print(f"✅ Analysis: {'ON' if pipeline.analyze_output else 'OFF'}")
        
        elif cmd_lower == 'n':
            pipeline.enhance_input = not pipeline.enhance_input
            print(f"✅ Enhancement: {'ON' if pipeline.enhance_input else 'OFF'}")
        
        elif cmd == 'S':
            pipeline.auto_save = not pipeline.auto_save
            print(f"✅ Auto-save: {'ON' if pipeline.auto_save else 'OFF'}")
        
        elif cmd_lower == 'o':
            import subprocess
            OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
            subprocess.Popen(f'explorer "{OUTPUT_DIR}"')
        
        elif cmd == '':
            try:
                result = pipeline.run_pipeline()
                if result and pipeline.analyzer:
                    if result.output_analysis:
                        pipeline.analyzer.print_analysis(result.output_analysis)
            except Exception as e:
                print(f"❌ Error: {e}")
        
        else:
            print("Unknown command. Press 'h' for help.")


# ================================================================
# Main Entry Point
# ================================================================

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="Enhanced Voice-to-Text-to-Voice Pipeline")
    parser.add_argument("--interactive", "-i", action="store_true", help="Interactive mode")
    parser.add_argument("--duration", "-d", type=float, default=5.0, help="Recording duration")
    parser.add_argument("--text", "-t", type=str, help="Text to synthesize")
    parser.add_argument("--voice", "-v", type=str, help="Voice sample path")
    parser.add_argument("--source-lang", "-sl", default="en", help="Source language")
    parser.add_argument("--target-lang", "-tl", default="en", help="Target language")
    parser.add_argument("--emotion", "-e", default="neutral", help="Emotion style")
    parser.add_argument("--no-enhance", action="store_true", help="Disable audio enhancement")
    parser.add_argument("--no-analyze", action="store_true", help="Disable voice analysis")
    
    args = parser.parse_args()
    
    if args.interactive:
        interactive_mode()
        return
    
    # Create pipeline with settings
    pipeline = VoiceToTextToVoiceV2(voice_sample_path=args.voice)
    pipeline.source_language = args.source_lang
    pipeline.target_language = args.target_lang
    pipeline.emotion = args.emotion
    pipeline.enhance_input = not args.no_enhance
    pipeline.analyze_output = not args.no_analyze
    
    if args.text:
        # Text-to-speech only
        text = pipeline.apply_emotion(args.text)
        audio = pipeline.synthesize(text)
        if audio is not None:
            pipeline.play_audio(audio)
    else:
        # Full pipeline
        pipeline.run_pipeline(duration=args.duration)


if __name__ == "__main__":
    main()
