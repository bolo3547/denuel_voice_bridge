"""
Voice Analyzer Module
=====================
Analyze voice characteristics and quality.

Features:
- Pitch analysis
- Speaking rate detection
- Voice similarity scoring
- Quality metrics (estimated MOS)
- Visualization helpers
"""

import numpy as np
from pathlib import Path
from dataclasses import dataclass
from typing import Optional, Tuple, List
import warnings
warnings.filterwarnings("ignore")


@dataclass
class VoiceAnalysis:
    """Container for voice analysis results."""
    duration: float
    pitch_mean: float
    pitch_std: float
    pitch_range: Tuple[float, float]
    speaking_rate_wpm: Optional[float]
    energy_db: float
    silence_ratio: float
    quality_score: float  # Estimated MOS (1-5)
    
    def to_dict(self) -> dict:
        return {
            "duration_seconds": round(self.duration, 2),
            "pitch_hz": {
                "mean": round(self.pitch_mean, 1),
                "std": round(self.pitch_std, 1),
                "min": round(self.pitch_range[0], 1),
                "max": round(self.pitch_range[1], 1)
            },
            "speaking_rate_wpm": round(self.speaking_rate_wpm, 1) if self.speaking_rate_wpm else None,
            "energy_db": round(self.energy_db, 1),
            "silence_ratio": round(self.silence_ratio, 2),
            "quality_score": round(self.quality_score, 2),
            "quality_label": self._quality_label()
        }
    
    def _quality_label(self) -> str:
        if self.quality_score >= 4.5:
            return "Excellent"
        elif self.quality_score >= 4.0:
            return "Good"
        elif self.quality_score >= 3.5:
            return "Fair"
        elif self.quality_score >= 3.0:
            return "Poor"
        else:
            return "Bad"


@dataclass
class SimilarityResult:
    """Container for voice similarity results."""
    similarity_score: float  # 0-1 scale
    pitch_similarity: float
    energy_similarity: float
    spectral_similarity: float
    
    def to_dict(self) -> dict:
        return {
            "overall_similarity": round(self.similarity_score * 100, 1),
            "pitch_match": round(self.pitch_similarity * 100, 1),
            "energy_match": round(self.energy_similarity * 100, 1),
            "spectral_match": round(self.spectral_similarity * 100, 1),
            "grade": self._grade()
        }
    
    def _grade(self) -> str:
        score = self.similarity_score
        if score >= 0.9:
            return "A+ (Excellent match)"
        elif score >= 0.8:
            return "A (Very similar)"
        elif score >= 0.7:
            return "B (Good match)"
        elif score >= 0.6:
            return "C (Moderate match)"
        else:
            return "D (Low similarity)"


class VoiceAnalyzer:
    """Voice analysis and comparison utilities."""
    
    def __init__(self, sample_rate: int = 22050):
        self.sample_rate = sample_rate
        self.librosa_available = False
        self._check_dependencies()
    
    def _check_dependencies(self):
        """Check for optional dependencies."""
        try:
            import librosa
            self.librosa_available = True
        except ImportError:
            print("⚠️  librosa not installed. Some features limited. Run: pip install librosa")
    
    def analyze(self, audio: np.ndarray, text: str = None) -> VoiceAnalysis:
        """
        Perform comprehensive voice analysis.
        
        Args:
            audio: Audio array
            text: Optional transcribed text for speaking rate
        
        Returns:
            VoiceAnalysis object with metrics
        """
        duration = len(audio) / self.sample_rate
        
        # Pitch analysis
        pitch_mean, pitch_std, pitch_range = self._analyze_pitch(audio)
        
        # Energy analysis
        energy_db = self._calculate_energy_db(audio)
        
        # Silence ratio
        silence_ratio = self._calculate_silence_ratio(audio)
        
        # Speaking rate (if text provided)
        speaking_rate = None
        if text:
            word_count = len(text.split())
            speaking_rate = (word_count / duration) * 60 if duration > 0 else 0
        
        # Estimate quality score
        quality_score = self._estimate_quality(audio, energy_db, silence_ratio)
        
        return VoiceAnalysis(
            duration=duration,
            pitch_mean=pitch_mean,
            pitch_std=pitch_std,
            pitch_range=pitch_range,
            speaking_rate_wpm=speaking_rate,
            energy_db=energy_db,
            silence_ratio=silence_ratio,
            quality_score=quality_score
        )
    
    def _analyze_pitch(self, audio: np.ndarray) -> Tuple[float, float, Tuple[float, float]]:
        """Extract pitch statistics using autocorrelation or librosa."""
        if self.librosa_available:
            try:
                import librosa
                
                # Extract pitch using piptrack
                pitches, magnitudes = librosa.piptrack(
                    y=audio, 
                    sr=self.sample_rate,
                    fmin=50,
                    fmax=500
                )
                
                # Get pitch values where magnitude is significant
                pitch_values = []
                for t in range(pitches.shape[1]):
                    index = magnitudes[:, t].argmax()
                    pitch = pitches[index, t]
                    if pitch > 0:
                        pitch_values.append(pitch)
                
                if pitch_values:
                    pitch_array = np.array(pitch_values)
                    return (
                        np.mean(pitch_array),
                        np.std(pitch_array),
                        (np.min(pitch_array), np.max(pitch_array))
                    )
            except Exception:
                pass
        
        # Fallback: simple autocorrelation-based pitch
        return self._simple_pitch_estimate(audio)
    
    def _simple_pitch_estimate(self, audio: np.ndarray) -> Tuple[float, float, Tuple[float, float]]:
        """Simple pitch estimation using zero-crossing rate."""
        # Zero crossing rate as rough pitch estimate
        zero_crossings = np.sum(np.abs(np.diff(np.sign(audio)))) / 2
        duration = len(audio) / self.sample_rate
        
        # Rough frequency estimate from zero crossings
        freq = zero_crossings / (2 * duration) if duration > 0 else 0
        
        # Clamp to reasonable voice range
        freq = max(50, min(freq, 400))
        
        return (freq, freq * 0.2, (freq * 0.7, freq * 1.3))
    
    def _calculate_energy_db(self, audio: np.ndarray) -> float:
        """Calculate RMS energy in dB."""
        rms = np.sqrt(np.mean(audio ** 2))
        if rms > 0:
            return 20 * np.log10(rms)
        return -100.0
    
    def _calculate_silence_ratio(self, audio: np.ndarray, threshold: float = 0.01) -> float:
        """Calculate ratio of silence in audio."""
        silent_samples = np.sum(np.abs(audio) < threshold)
        return silent_samples / len(audio) if len(audio) > 0 else 1.0
    
    def _estimate_quality(self, audio: np.ndarray, energy_db: float, 
                         silence_ratio: float) -> float:
        """
        Estimate Mean Opinion Score (MOS) based on audio characteristics.
        This is a heuristic estimation, not a proper MOS measurement.
        """
        score = 4.0  # Start with good baseline
        
        # Penalize very quiet audio
        if energy_db < -35:
            score -= 1.0
        elif energy_db < -30:
            score -= 0.5
        
        # Penalize too much silence (bad recording)
        if silence_ratio > 0.7:
            score -= 1.0
        elif silence_ratio > 0.5:
            score -= 0.5
        
        # Penalize clipping
        clipping_ratio = np.sum(np.abs(audio) > 0.99) / len(audio)
        if clipping_ratio > 0.01:
            score -= 1.0
        elif clipping_ratio > 0.001:
            score -= 0.5
        
        # Check for DC offset
        dc_offset = np.abs(np.mean(audio))
        if dc_offset > 0.1:
            score -= 0.5
        
        # Bonus for good signal characteristics
        if -25 <= energy_db <= -15 and 0.2 <= silence_ratio <= 0.5:
            score += 0.5
        
        return max(1.0, min(5.0, score))
    
    def compare_voices(self, audio1: np.ndarray, audio2: np.ndarray) -> SimilarityResult:
        """
        Compare two voice samples for similarity.
        
        Args:
            audio1: First audio sample
            audio2: Second audio sample
        
        Returns:
            SimilarityResult with comparison metrics
        """
        # Pitch similarity
        pitch1 = self._analyze_pitch(audio1)
        pitch2 = self._analyze_pitch(audio2)
        pitch_sim = 1.0 - min(abs(pitch1[0] - pitch2[0]) / 200, 1.0)
        
        # Energy similarity
        energy1 = self._calculate_energy_db(audio1)
        energy2 = self._calculate_energy_db(audio2)
        energy_sim = 1.0 - min(abs(energy1 - energy2) / 30, 1.0)
        
        # Spectral similarity (using MFCC if librosa available)
        spectral_sim = self._calculate_spectral_similarity(audio1, audio2)
        
        # Overall similarity (weighted average)
        overall = (pitch_sim * 0.3 + energy_sim * 0.2 + spectral_sim * 0.5)
        
        return SimilarityResult(
            similarity_score=overall,
            pitch_similarity=pitch_sim,
            energy_similarity=energy_sim,
            spectral_similarity=spectral_sim
        )
    
    def _calculate_spectral_similarity(self, audio1: np.ndarray, 
                                        audio2: np.ndarray) -> float:
        """Calculate spectral similarity using MFCCs."""
        if not self.librosa_available:
            # Fallback: simple correlation
            min_len = min(len(audio1), len(audio2))
            corr = np.corrcoef(audio1[:min_len], audio2[:min_len])[0, 1]
            return max(0, (corr + 1) / 2)
        
        try:
            import librosa
            
            # Extract MFCCs
            mfcc1 = librosa.feature.mfcc(y=audio1, sr=self.sample_rate, n_mfcc=13)
            mfcc2 = librosa.feature.mfcc(y=audio2, sr=self.sample_rate, n_mfcc=13)
            
            # Calculate mean MFCC vectors
            mean1 = np.mean(mfcc1, axis=1)
            mean2 = np.mean(mfcc2, axis=1)
            
            # Cosine similarity
            dot = np.dot(mean1, mean2)
            norm1 = np.linalg.norm(mean1)
            norm2 = np.linalg.norm(mean2)
            
            if norm1 > 0 and norm2 > 0:
                cosine_sim = dot / (norm1 * norm2)
                return (cosine_sim + 1) / 2  # Normalize to 0-1
            
        except Exception:
            pass
        
        return 0.5  # Default moderate similarity
    
    def print_analysis(self, analysis: VoiceAnalysis):
        """Pretty print voice analysis results."""
        print("\n" + "="*50)
        print("📊 Voice Analysis Report")
        print("="*50)
        print(f"   Duration:        {analysis.duration:.2f} seconds")
        print(f"   Pitch (mean):    {analysis.pitch_mean:.1f} Hz")
        print(f"   Pitch (range):   {analysis.pitch_range[0]:.1f} - {analysis.pitch_range[1]:.1f} Hz")
        print(f"   Energy:          {analysis.energy_db:.1f} dB")
        print(f"   Silence ratio:   {analysis.silence_ratio:.0%}")
        if analysis.speaking_rate_wpm:
            print(f"   Speaking rate:   {analysis.speaking_rate_wpm:.0f} WPM")
        print(f"   Quality score:   {analysis.quality_score:.1f}/5.0 ({analysis._quality_label()})")
        print("="*50)
    
    def print_similarity(self, result: SimilarityResult):
        """Pretty print similarity results."""
        print("\n" + "="*50)
        print("🎯 Voice Similarity Report")
        print("="*50)
        print(f"   Overall match:   {result.similarity_score*100:.1f}%")
        print(f"   Pitch match:     {result.pitch_similarity*100:.1f}%")
        print(f"   Energy match:    {result.energy_similarity*100:.1f}%")
        print(f"   Spectral match:  {result.spectral_similarity*100:.1f}%")
        print(f"   Grade:           {result._grade()}")
        print("="*50)


# Quick test
if __name__ == "__main__":
    print("📊 Voice Analyzer Module")
    print("-" * 40)
    
    analyzer = VoiceAnalyzer()
    
    # Test with synthetic audio
    duration = 2.0
    t = np.linspace(0, duration, int(22050 * duration))
    
    # Create test audio (simulated speech-like)
    audio = np.sin(2 * np.pi * 150 * t) * 0.3  # ~150Hz fundamental
    audio += np.sin(2 * np.pi * 300 * t) * 0.15  # Harmonic
    audio = (audio + np.random.randn(len(t)) * 0.02).astype(np.float32)
    
    analysis = analyzer.analyze(audio, "test speech text here")
    analyzer.print_analysis(analysis)
    
    print("\n✅ Voice analyzer ready!")
