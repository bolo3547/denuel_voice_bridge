"""
Voice-to-Text-to-Voice Pipeline
================================
Records your voice, transcribes it with Whisper, 
then synthesizes it back using XTTS with your voice profile.

Usage:
    python ai/pipelines/voice_to_text_to_voice.py

Flow:
    🎤 Record → 📝 Transcribe (Whisper) → 🔊 Synthesize (XTTS)
"""

import os
import sys
import tempfile
import wave
from pathlib import Path

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

# Configuration
SAMPLE_RATE = 22050
CHANNELS = 1
RECORDING_SECONDS = 5  # Default recording duration

# Paths
VOICE_SAMPLES_DIR = PROJECT_ROOT / "data" / "voice_profile_clean"
EMBEDDINGS_DIR = PROJECT_ROOT / "data" / "embeddings"
OUTPUT_DIR = PROJECT_ROOT / "data" / "outputs"


class VoiceToTextToVoice:
    """Pipeline: Voice → Text → Voice (with cloning)"""
    
    def __init__(self, voice_sample_path: str = None):
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        print(f"🖥️  Using device: {self.device}")
        
        self.whisper_model = None
        self.tts_model = None
        self.voice_sample_path = voice_sample_path
        
        # Settings
        self.recording_duration = RECORDING_SECONDS
        self.auto_save = False
        self.language = "en"
        
        # State
        self.last_audio_out = None
        self.last_text = None
        
        # Ensure output directory exists
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        
    def load_whisper(self):
        """Load Whisper model for speech-to-text."""
        if self.whisper_model is not None:
            return
            
        print("📥 Loading Whisper model...")
        try:
            import whisper
            self.whisper_model = whisper.load_model("base", device=self.device)
            print("✅ Whisper loaded!")
        except ImportError:
            print("❌ Whisper not installed. Run: pip install openai-whisper")
            raise
            
    def load_tts(self):
        """Load XTTS model for text-to-speech."""
        if self.tts_model is not None:
            return
            
        print("📥 Loading XTTS model (this may take a moment)...")
        try:
            import os
            # Auto-accept XTTS license for non-commercial use
            os.environ["COQUI_TOS_AGREED"] = "1"
            
            from TTS.api import TTS
            # XTTS v2 supports voice cloning
            self.tts_model = TTS("tts_models/multilingual/multi-dataset/xtts_v2").to(self.device)
            print("✅ XTTS loaded!")
        except ImportError:
            print("❌ TTS not installed. Run: pip install coqui-tts")
            raise
        except Exception as e:
            print(f"❌ Error loading XTTS: {e}")
            raise
            
    def record_audio(self, duration: float = RECORDING_SECONDS) -> np.ndarray:
        """Record audio from microphone."""
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
    
    def transcribe(self, audio: np.ndarray) -> str:
        """Transcribe audio to text using Whisper."""
        self.load_whisper()
        
        print("📝 Transcribing...")
        
        # Whisper expects float32 audio
        if audio.dtype != np.float32:
            audio = audio.astype(np.float32)
        
        # Whisper expects 16kHz, resample if needed
        if SAMPLE_RATE != 16000:
            import scipy.signal
            audio = scipy.signal.resample(audio, int(len(audio) * 16000 / SAMPLE_RATE))
        
        result = self.whisper_model.transcribe(audio, fp16=(self.device == "cuda"))
        text = result["text"].strip()
        
        print(f"📜 Transcribed: \"{text}\"")
        return text
    
    def synthesize(self, text: str, output_path: str = None) -> np.ndarray:
        """Synthesize text to speech using XTTS with voice cloning."""
        self.load_tts()
        
        if not text:
            print("⚠️  No text to synthesize!")
            return None
        
        print("🔊 Synthesizing speech...")
        
        # Find a voice sample for cloning
        voice_sample = self._get_voice_sample()
        
        if voice_sample:
            print(f"   Using voice sample: {Path(voice_sample).name}")
            # Generate with voice cloning
            wav = self.tts_model.tts(
                text=text,
                speaker_wav=voice_sample,
                language="en"
            )
        else:
            print("   ⚠️  No voice sample found, using default voice")
            # Generate with default voice
            wav = self.tts_model.tts(text=text, language="en")
        
        audio = np.array(wav, dtype=np.float32)
        
        # Save if output path specified
        if output_path:
            self._save_wav(output_path, audio)
            print(f"💾 Saved to: {output_path}")
        
        print("✅ Synthesis complete!")
        return audio
    
    def _get_voice_sample(self) -> str:
        """Get a voice sample for cloning."""
        # Check explicit path first
        if self.voice_sample_path and Path(self.voice_sample_path).exists():
            if Path(self.voice_sample_path).stat().st_size > 1000:  # At least 1KB
                return str(self.voice_sample_path)
        
        # Check raw samples directory first (user recordings)
        raw_dir = PROJECT_ROOT / "data" / "voice_profile_raw"
        if raw_dir.exists():
            samples = [f for f in raw_dir.glob("*.wav") if f.stat().st_size > 1000]
            if samples:
                # Use the most recent sample
                samples.sort(key=lambda x: x.stat().st_mtime, reverse=True)
                return str(samples[0])
        
        # Check clean samples directory
        if VOICE_SAMPLES_DIR.exists():
            samples = [f for f in VOICE_SAMPLES_DIR.glob("*.wav") if f.stat().st_size > 1000]
            if samples:
                return str(samples[0])
        
        return None
    
    def _save_wav(self, filepath: str, audio: np.ndarray):
        """Save audio to WAV file."""
        audio_int = (audio * 32767).astype(np.int16)
        
        with wave.open(filepath, 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(22050)
            wf.writeframes(audio_int.tobytes())
    
    def play_audio(self, audio: np.ndarray):
        """Play audio through speakers."""
        print("🔊 Playing...")
        sd.play(audio, 22050)
        sd.wait()
        print("✅ Playback complete!")
    
    def run_pipeline(self, duration: float = None, save: bool = None):
        """Run the full Voice → Text → Voice pipeline."""
        duration = duration or self.recording_duration
        save = save if save is not None else self.auto_save
        
        print("\n" + "="*50)
        print("🎙️  Voice-to-Text-to-Voice Pipeline")
        print("="*50 + "\n")
        
        # Step 1: Record
        audio_in = self.record_audio(duration)
        
        # Step 2: Transcribe
        text = self.transcribe(audio_in)
        
        if not text:
            print("❌ No speech detected!")
            return
        
        # Step 3: Synthesize
        output_path = None
        if save:
            import datetime
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            output_path = str(OUTPUT_DIR / f"clone_{timestamp}.wav")
        
        audio_out = self.synthesize(text, output_path=output_path)
        
        # Store for later use
        self.last_audio_out = audio_out
        self.last_text = text
        
        if audio_out is not None:
            # Step 4: Play result
            print("\n▶️  Playing synthesized voice...")
            self.play_audio(audio_out)
        
        print("\n✅ Pipeline complete!")
        return text, audio_out
    
    def save_last_output(self, filename: str = None):
        """Save the last synthesized audio to a file."""
        if self.last_audio_out is None:
            print("⚠️  No audio to save! Run the pipeline first.")
            return None
        
        import datetime
        if not filename:
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"clone_{timestamp}.wav"
        
        filepath = OUTPUT_DIR / filename
        self._save_wav(str(filepath), self.last_audio_out)
        print(f"💾 Saved to: {filepath}")
        return str(filepath)
    
    def list_voice_samples(self):
        """List available voice samples."""
        raw_dir = PROJECT_ROOT / "data" / "voice_profile_raw"
        samples = []
        
        if raw_dir.exists():
            samples.extend([f for f in raw_dir.glob("*.wav") if f.stat().st_size > 1000])
        if VOICE_SAMPLES_DIR.exists():
            samples.extend([f for f in VOICE_SAMPLES_DIR.glob("*.wav") if f.stat().st_size > 1000])
        
        samples.sort(key=lambda x: x.stat().st_mtime, reverse=True)
        return samples
    
    def replay_last(self):
        """Replay the last synthesized audio."""
        if self.last_audio_out is None:
            print("⚠️  No audio to replay! Run the pipeline first.")
            return
        self.play_audio(self.last_audio_out)


def print_help():
    """Print help menu."""
    print("\n" + "-"*50)
    print("📖 Commands:")
    print("-"*50)
    print("   ENTER    - Record and process")
    print("   t        - Type text to synthesize")
    print("   r        - Replay last output")
    print("   s        - Save last output to file")
    print("   d <sec>  - Set recording duration (e.g., 'd 10')")
    print("   v        - List/select voice samples")
    print("   a        - Toggle auto-save mode")
    print("   o        - Open outputs folder")
    print("   h        - Show this help")
    print("   q        - Quit")
    print("-"*50 + "\n")


def interactive_mode():
    """Run in interactive mode."""
    print("\n" + "="*50)
    print("🎙️  Voice-to-Text-to-Voice Pipeline")
    print("="*50)
    
    pipeline = VoiceToTextToVoice()
    print_help()
    print(f"⚙️  Settings: duration={pipeline.recording_duration}s, auto_save={pipeline.auto_save}")
    print()
    
    while True:
        try:
            cmd = input(">>> ").strip().lower()
        except EOFError:
            break
        
        if cmd == 'q':
            print("👋 Goodbye!")
            break
        
        elif cmd == 'h':
            print_help()
            
        elif cmd == 't':
            text = input("Enter text to synthesize: ").strip()
            if text:
                audio = pipeline.synthesize(text)
                pipeline.last_audio_out = audio
                pipeline.last_text = text
                if audio is not None:
                    pipeline.play_audio(audio)
        
        elif cmd == 'r':
            pipeline.replay_last()
        
        elif cmd == 's':
            pipeline.save_last_output()
        
        elif cmd.startswith('d '):
            try:
                duration = float(cmd.split()[1])
                if 1 <= duration <= 30:
                    pipeline.recording_duration = duration
                    print(f"✅ Recording duration set to {duration} seconds")
                else:
                    print("⚠️  Duration must be between 1 and 30 seconds")
            except (ValueError, IndexError):
                print("⚠️  Usage: d <seconds> (e.g., 'd 10')")
        
        elif cmd == 'v':
            samples = pipeline.list_voice_samples()
            if not samples:
                print("⚠️  No voice samples found! Record some first.")
            else:
                print(f"\n🎤 Available voice samples ({len(samples)}):")
                for i, s in enumerate(samples[:10], 1):
                    size_kb = s.stat().st_size / 1024
                    current = " ← current" if str(s) == pipeline._get_voice_sample() else ""
                    print(f"   {i}. {s.name} ({size_kb:.1f} KB){current}")
                
                choice = input("\nSelect sample # (or ENTER to keep current): ").strip()
                if choice.isdigit() and 1 <= int(choice) <= len(samples):
                    pipeline.voice_sample_path = str(samples[int(choice)-1])
                    print(f"✅ Voice sample set to: {samples[int(choice)-1].name}")
        
        elif cmd == 'a':
            pipeline.auto_save = not pipeline.auto_save
            status = "ON" if pipeline.auto_save else "OFF"
            print(f"✅ Auto-save is now {status}")
        
        elif cmd == 'o':
            import subprocess
            OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
            subprocess.Popen(f'explorer "{OUTPUT_DIR}"')
            print(f"📂 Opened: {OUTPUT_DIR}")
                    
        elif cmd == '':
            try:
                pipeline.run_pipeline()
            except Exception as e:
                print(f"❌ Error: {e}")
        else:
            print("Unknown command. Press 'h' for help.")


def main():
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Voice-to-Text-to-Voice Pipeline")
    parser.add_argument("--duration", "-d", type=float, default=5.0,
                       help="Recording duration in seconds")
    parser.add_argument("--text", "-t", type=str,
                       help="Text to synthesize (skip recording)")
    parser.add_argument("--voice", "-v", type=str,
                       help="Path to voice sample for cloning")
    parser.add_argument("--interactive", "-i", action="store_true",
                       help="Run in interactive mode")
    
    args = parser.parse_args()
    
    if args.interactive:
        interactive_mode()
        return
    
    pipeline = VoiceToTextToVoice(voice_sample_path=args.voice)
    
    if args.text:
        # Text-to-speech only
        audio = pipeline.synthesize(args.text)
        if audio is not None:
            pipeline.play_audio(audio)
    else:
        # Full pipeline
        pipeline.run_pipeline(duration=args.duration)


if __name__ == "__main__":
    main()
