"""
Audio Enhancement Module
========================
Clean up and enhance audio quality.

Features:
- Background noise removal
- Voice clarity enhancement
- Volume normalization
- Silence trimming
"""

import numpy as np
from pathlib import Path
import warnings
warnings.filterwarnings("ignore")


class AudioEnhancer:
    """Audio enhancement and cleanup utilities."""
    
    def __init__(self, sample_rate: int = 22050):
        self.sample_rate = sample_rate
        self.noisereduce_available = False
        self._check_dependencies()
    
    def _check_dependencies(self):
        """Check for optional enhancement dependencies."""
        try:
            import noisereduce
            self.noisereduce_available = True
        except ImportError:
            print("⚠️  noisereduce not installed. Run: pip install noisereduce")
    
    def normalize_volume(self, audio: np.ndarray, target_db: float = -20.0) -> np.ndarray:
        """
        Normalize audio volume to target dB level.
        
        Args:
            audio: Input audio array
            target_db: Target loudness in dB (default -20dB)
        
        Returns:
            Normalized audio array
        """
        if len(audio) == 0:
            return audio
        
        # Calculate current RMS
        rms = np.sqrt(np.mean(audio ** 2))
        if rms == 0:
            return audio
        
        # Calculate target RMS from dB
        target_rms = 10 ** (target_db / 20)
        
        # Apply gain
        gain = target_rms / rms
        normalized = audio * gain
        
        # Clip to prevent distortion
        normalized = np.clip(normalized, -1.0, 1.0)
        
        return normalized
    
    def remove_noise(self, audio: np.ndarray, noise_reduce_strength: float = 0.75) -> np.ndarray:
        """
        Remove background noise from audio.
        
        Args:
            audio: Input audio array
            noise_reduce_strength: Strength of noise reduction (0.0-1.0)
        
        Returns:
            Cleaned audio array
        """
        if not self.noisereduce_available:
            print("⚠️  Noise reduction skipped (noisereduce not installed)")
            return audio
        
        import noisereduce as nr
        
        # Apply noise reduction
        reduced = nr.reduce_noise(
            y=audio,
            sr=self.sample_rate,
            prop_decrease=noise_reduce_strength,
            stationary=False
        )
        
        return reduced.astype(np.float32)
    
    def trim_silence(self, audio: np.ndarray, threshold_db: float = -40.0, 
                     min_silence_duration: float = 0.1) -> np.ndarray:
        """
        Trim silence from beginning and end of audio.
        
        Args:
            audio: Input audio array
            threshold_db: Silence threshold in dB
            min_silence_duration: Minimum silence duration to keep (seconds)
        
        Returns:
            Trimmed audio array
        """
        if len(audio) == 0:
            return audio
        
        threshold = 10 ** (threshold_db / 20)
        min_samples = int(min_silence_duration * self.sample_rate)
        
        # Find non-silent regions
        abs_audio = np.abs(audio)
        
        # Find start
        start_idx = 0
        for i in range(len(audio)):
            if abs_audio[i] > threshold:
                start_idx = max(0, i - min_samples)
                break
        
        # Find end
        end_idx = len(audio)
        for i in range(len(audio) - 1, -1, -1):
            if abs_audio[i] > threshold:
                end_idx = min(len(audio), i + min_samples)
                break
        
        return audio[start_idx:end_idx]
    
    def enhance_clarity(self, audio: np.ndarray) -> np.ndarray:
        """
        Enhance voice clarity using simple EQ boost.
        Boosts presence frequencies (2-4kHz) for clearer speech.
        
        Args:
            audio: Input audio array
        
        Returns:
            Enhanced audio array
        """
        try:
            from scipy import signal
            
            # Design a gentle presence boost filter (2-4kHz)
            nyquist = self.sample_rate / 2
            low_freq = 2000 / nyquist
            high_freq = min(4000 / nyquist, 0.95)
            
            if low_freq >= high_freq or low_freq >= 1:
                return audio
            
            # Create bandpass filter for presence frequencies
            b, a = signal.butter(2, [low_freq, high_freq], btype='band')
            presence = signal.filtfilt(b, a, audio)
            
            # Mix original with boosted presence
            enhanced = audio + (presence * 0.3)
            
            # Normalize to prevent clipping
            max_val = np.max(np.abs(enhanced))
            if max_val > 1.0:
                enhanced = enhanced / max_val
            
            return enhanced.astype(np.float32)
            
        except ImportError:
            print("⚠️  scipy not installed, skipping clarity enhancement")
            return audio
    
    def full_enhance(self, audio: np.ndarray, 
                     denoise: bool = True,
                     normalize: bool = True,
                     trim: bool = True,
                     clarity: bool = True) -> np.ndarray:
        """
        Apply full enhancement pipeline.
        
        Args:
            audio: Input audio array
            denoise: Apply noise reduction
            normalize: Apply volume normalization
            trim: Trim silence
            clarity: Enhance voice clarity
        
        Returns:
            Enhanced audio array
        """
        result = audio.copy()
        
        if trim:
            result = self.trim_silence(result)
        
        if denoise:
            result = self.remove_noise(result)
        
        if clarity:
            result = self.enhance_clarity(result)
        
        if normalize:
            result = self.normalize_volume(result)
        
        return result
    
    def get_audio_stats(self, audio: np.ndarray) -> dict:
        """
        Get audio statistics.
        
        Args:
            audio: Input audio array
        
        Returns:
            Dictionary of audio statistics
        """
        if len(audio) == 0:
            return {"error": "Empty audio"}
        
        rms = np.sqrt(np.mean(audio ** 2))
        rms_db = 20 * np.log10(rms) if rms > 0 else -100
        
        peak = np.max(np.abs(audio))
        peak_db = 20 * np.log10(peak) if peak > 0 else -100
        
        duration = len(audio) / self.sample_rate
        
        # Simple silence detection
        threshold = 0.01
        non_silent = np.sum(np.abs(audio) > threshold) / len(audio)
        
        return {
            "duration_seconds": round(duration, 2),
            "rms_db": round(rms_db, 1),
            "peak_db": round(peak_db, 1),
            "speech_ratio": round(non_silent, 2),
            "sample_rate": self.sample_rate,
            "samples": len(audio)
        }


# Quick test
if __name__ == "__main__":
    print("🎛️  Audio Enhancer Module")
    print("-" * 40)
    
    enhancer = AudioEnhancer()
    
    # Test with synthetic audio
    duration = 2.0
    t = np.linspace(0, duration, int(22050 * duration))
    
    # Create noisy sine wave
    clean = np.sin(2 * np.pi * 440 * t) * 0.3
    noise = np.random.randn(len(t)) * 0.05
    noisy = (clean + noise).astype(np.float32)
    
    print(f"Original stats: {enhancer.get_audio_stats(noisy)}")
    
    enhanced = enhancer.full_enhance(noisy)
    print(f"Enhanced stats: {enhancer.get_audio_stats(enhanced)}")
    
    print("\n✅ Audio enhancer ready!")
