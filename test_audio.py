"""
Quick Audio Test
================
Test if audio playback is working.
"""
import numpy as np

print("🔊 Audio Test")
print("="*40)

try:
    import sounddevice as sd
    
    # List devices
    print("\n📋 Available audio devices:")
    print(sd.query_devices())
    
    print(f"\n🎧 Default output device: {sd.default.device[1]}")
    
    # Test playback
    print("\n🔔 Playing test tone (440Hz beep)...")
    duration = 1.0
    sample_rate = 22050
    t = np.linspace(0, duration, int(sample_rate * duration))
    audio = (np.sin(2 * np.pi * 440 * t) * 0.5).astype(np.float32)
    
    sd.play(audio, sample_rate)
    sd.wait()
    
    print("✅ Test complete!")
    print("\n❓ Did you hear a beep?")
    print("   - If YES: Audio is working, the issue is elsewhere")
    print("   - If NO: Check your speakers/headphones and volume")
    
except ImportError:
    print("❌ sounddevice not installed!")
    print("   Run: pip install sounddevice")
except Exception as e:
    print(f"❌ Error: {e}")
