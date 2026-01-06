"""
Voice Recorder Tool for Denuel Voice Bridge
============================================
Records voice samples for voice cloning training.

Usage:
    python tools/audio_tools/voice_recorder.py

Controls:
    - Press ENTER to start/stop recording
    - Press 'q' to quit
    - Press 'p' to playback last recording
"""

import os
import sys
import wave
import threading
import datetime
from pathlib import Path

try:
    import sounddevice as sd
    import numpy as np
except ImportError:
    print("Missing dependencies. Install with:")
    print("  pip install sounddevice numpy")
    sys.exit(1)

# Configuration
SAMPLE_RATE = 22050  # Standard for TTS training
CHANNELS = 1         # Mono audio
DTYPE = np.int16     # 16-bit audio

# Paths
PROJECT_ROOT = Path(__file__).parent.parent.parent
RAW_SAMPLES_DIR = PROJECT_ROOT / "data" / "voice_profile_raw"
CLEAN_SAMPLES_DIR = PROJECT_ROOT / "data" / "voice_profile_clean"


class VoiceRecorder:
    """Simple voice recorder for collecting training samples."""
    
    def __init__(self, output_dir: Path = RAW_SAMPLES_DIR):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        self.recording = False
        self.audio_data = []
        self.last_recording_path = None
        
    def _record_callback(self, indata, frames, time, status):
        """Callback for audio stream."""
        if status:
            print(f"Recording status: {status}")
        if self.recording:
            self.audio_data.append(indata.copy())
    
    def start_recording(self):
        """Start recording audio."""
        self.recording = True
        self.audio_data = []
        print("🎙️  Recording... (Press ENTER to stop)")
        
    def stop_recording(self) -> str:
        """Stop recording and save to file."""
        self.recording = False
        
        if not self.audio_data:
            print("⚠️  No audio recorded!")
            return None
            
        # Combine all audio chunks
        audio = np.concatenate(self.audio_data, axis=0)
        
        # Generate filename with timestamp
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"voice_sample_{timestamp}.wav"
        filepath = self.output_dir / filename
        
        # Save as WAV file
        self._save_wav(filepath, audio)
        
        self.last_recording_path = filepath
        duration = len(audio) / SAMPLE_RATE
        print(f"✅ Saved: {filename} ({duration:.1f}s)")
        
        return str(filepath)
    
    def _save_wav(self, filepath: Path, audio: np.ndarray):
        """Save audio data to WAV file."""
        # Convert float to int16 if needed
        if audio.dtype == np.float32:
            audio = (audio * 32767).astype(np.int16)
        
        with wave.open(str(filepath), 'wb') as wf:
            wf.setnchannels(CHANNELS)
            wf.setsampwidth(2)  # 16-bit = 2 bytes
            wf.setframerate(SAMPLE_RATE)
            wf.writeframes(audio.tobytes())
    
    def playback(self, filepath: str = None):
        """Play back a recorded file."""
        filepath = filepath or self.last_recording_path
        
        if not filepath or not Path(filepath).exists():
            print("⚠️  No recording to play!")
            return
            
        print(f"🔊 Playing: {Path(filepath).name}")
        
        with wave.open(str(filepath), 'rb') as wf:
            audio = np.frombuffer(wf.readframes(wf.getnframes()), dtype=np.int16)
            sd.play(audio, wf.getframerate())
            sd.wait()
        
        print("✅ Playback complete")
    
    def list_recordings(self) -> list:
        """List all recorded samples."""
        recordings = list(self.output_dir.glob("*.wav"))
        return sorted(recordings, key=lambda x: x.stat().st_mtime, reverse=True)
    
    def get_total_duration(self) -> float:
        """Get total duration of all recordings in seconds."""
        total = 0.0
        for filepath in self.output_dir.glob("*.wav"):
            try:
                with wave.open(str(filepath), 'rb') as wf:
                    frames = wf.getnframes()
                    rate = wf.getframerate()
                    total += frames / rate
            except Exception:
                pass
        return total


def print_status(recorder: VoiceRecorder):
    """Print current recording status."""
    recordings = recorder.list_recordings()
    total_duration = recorder.get_total_duration()
    
    print("\n" + "="*50)
    print("📊 Voice Sample Collection Status")
    print("="*50)
    print(f"   Samples recorded: {len(recordings)}")
    print(f"   Total duration:   {total_duration:.1f}s ({total_duration/60:.1f} min)")
    print(f"   Target duration:  300s (5 min minimum)")
    print(f"   Progress:         {min(100, total_duration/300*100):.0f}%")
    print("="*50)
    
    if total_duration < 300:
        remaining = 300 - total_duration
        print(f"💡 Record {remaining:.0f}s more for best voice cloning quality")
    else:
        print("✅ You have enough samples for voice cloning!")
    print()


def print_prompts():
    """Print suggested recording prompts."""
    prompts = [
        "The quick brown fox jumps over the lazy dog.",
        "Hello, my name is Denuel and this is my voice.",
        "I enjoy building things with technology and code.",
        "The weather today is absolutely beautiful.",
        "Please leave a message after the beep.",
        "Welcome to my voice assistant, how can I help you?",
        "Reading books is one of my favorite activities.",
        "Let me tell you about an interesting story.",
        "Numbers one two three four five six seven eight nine ten.",
        "The alphabet: A B C D E F G H I J K L M N O P Q R S T U V W X Y Z.",
    ]
    
    print("\n📝 Suggested prompts to read (vary your tone!):")
    print("-" * 50)
    for i, prompt in enumerate(prompts, 1):
        print(f"   {i}. {prompt}")
    print("-" * 50)
    print()


def main():
    """Main recording loop."""
    print("\n" + "="*50)
    print("🎙️  Denuel Voice Bridge - Voice Recorder")
    print("="*50)
    print("\nControls:")
    print("   ENTER  - Start/Stop recording")
    print("   p      - Playback last recording")
    print("   l      - List all recordings")
    print("   s      - Show status")
    print("   h      - Show prompts to read")
    print("   q      - Quit")
    print()
    
    recorder = VoiceRecorder()
    print_status(recorder)
    
    # Start audio stream
    stream = sd.InputStream(
        samplerate=SAMPLE_RATE,
        channels=CHANNELS,
        dtype='float32',
        callback=recorder._record_callback
    )
    
    try:
        with stream:
            while True:
                cmd = input(">>> ").strip().lower()
                
                if cmd == 'q':
                    print("👋 Goodbye!")
                    break
                    
                elif cmd == 'p':
                    recorder.playback()
                    
                elif cmd == 'l':
                    recordings = recorder.list_recordings()
                    print(f"\n📁 Recordings ({len(recordings)} files):")
                    for r in recordings[:10]:
                        print(f"   - {r.name}")
                    if len(recordings) > 10:
                        print(f"   ... and {len(recordings)-10} more")
                    print()
                    
                elif cmd == 's':
                    print_status(recorder)
                    
                elif cmd == 'h':
                    print_prompts()
                    
                elif cmd == '':
                    if not recorder.recording:
                        recorder.start_recording()
                    else:
                        recorder.stop_recording()
                        print_status(recorder)
                        
                else:
                    print("Unknown command. Press 'h' for help.")
                    
    except KeyboardInterrupt:
        print("\n👋 Interrupted. Goodbye!")


if __name__ == "__main__":
    main()
