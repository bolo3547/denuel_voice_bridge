"""
DENUEL VOICE BRIDGE - Core Processing Pipeline
===============================================
Assistive speech system for pronunciation support.

PIPELINE:
    INPUT:  Microphone → VAD → Noise Suppression → Speaker Isolation
    PROCESS: Cleaned Voice → Whisper → Text Normalization
    OUTPUT: Normalized Text → XTTS (user's voice) → Clear Speech

BEHAVIOR:
    - Never criticizes or corrects the user
    - Silently normalizes pronunciation on output
    - Preserves meaning and identity
    - Ignores background noise and other voices

Usage:
    python ai/pipelines/denuel_voice_bridge.py
"""

import os
import sys
import wave
import json
import time
from pathlib import Path
from datetime import datetime
from typing import Optional, Tuple, List, Dict
from collections import deque

import numpy as np

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

try:
    import torch
    import sounddevice as sd
except ImportError as e:
    print(f"Missing dependency: {e}")
    print("Install with: pip install torch sounddevice")
    sys.exit(1)


# =============================================================================
# CONFIGURATION
# =============================================================================

SAMPLE_RATE = 16000  # Whisper expects 16kHz
CHANNELS = 1
CHUNK_DURATION = 0.1  # 100ms chunks for VAD

# Paths
VOICE_SAMPLES_DIR = PROJECT_ROOT / "data" / "voice_profile_clean"
RAW_SAMPLES_DIR = PROJECT_ROOT / "data" / "voice_profile_raw"
OUTPUT_DIR = PROJECT_ROOT / "data" / "outputs"
USER_MEMORY_PATH = PROJECT_ROOT / "data" / "user_word_memory.json"
PHRASE_MEMORY_PATH = PROJECT_ROOT / "data" / "phrase_memory.json"


# =============================================================================
# VOICE ACTIVITY DETECTION (VAD)
# =============================================================================

class VoiceActivityDetector:
    """
    Detects when the user is speaking.
    
    Uses energy-based detection with adaptive threshold.
    Ignores brief sounds (coughs, clicks) and background noise.
    """
    
    def __init__(self, sample_rate: int = SAMPLE_RATE):
        self.sample_rate = sample_rate
        self.energy_threshold = 0.01  # Will adapt
        self.silence_threshold = 0.005
        
        # Adaptive threshold tracking
        self.energy_history = deque(maxlen=50)
        self.noise_floor = 0.001
        
        # Speech state tracking
        self.is_speaking = False
        self.speech_frames = 0
        self.silence_frames = 0
        
        # Require minimum speech duration to start (avoid false triggers)
        self.min_speech_frames = 3  # ~300ms
        # Allow brief pauses during speech
        self.max_silence_frames = 10  # ~1s pause allowed
        
    def update_noise_floor(self, energy: float):
        """Update adaptive noise floor estimate."""
        if energy < self.noise_floor * 2:
            self.noise_floor = 0.95 * self.noise_floor + 0.05 * energy
        self.energy_threshold = self.noise_floor * 3
        
    def process_chunk(self, audio_chunk: np.ndarray) -> bool:
        """
        Process audio chunk and return True if speech detected.
        
        Args:
            audio_chunk: Audio samples (float32, mono)
            
        Returns:
            True if user is currently speaking
        """
        # Calculate RMS energy
        energy = np.sqrt(np.mean(audio_chunk ** 2))
        self.energy_history.append(energy)
        
        # Update adaptive threshold
        self.update_noise_floor(energy)
        
        # Determine if this chunk contains speech
        is_voice = energy > self.energy_threshold
        
        if is_voice:
            self.speech_frames += 1
            self.silence_frames = 0
        else:
            self.silence_frames += 1
            if self.silence_frames > self.max_silence_frames:
                self.speech_frames = 0
        
        # State machine for speech detection
        if not self.is_speaking:
            # Need sustained speech to start
            if self.speech_frames >= self.min_speech_frames:
                self.is_speaking = True
        else:
            # Allow brief pauses, but end on sustained silence
            if self.silence_frames > self.max_silence_frames:
                self.is_speaking = False
                self.speech_frames = 0
        
        return self.is_speaking
    
    def reset(self):
        """Reset state for new utterance."""
        self.is_speaking = False
        self.speech_frames = 0
        self.silence_frames = 0


# =============================================================================
# NOISE SUPPRESSION
# =============================================================================

class NoiseSuppressor:
    """
    Removes background noise from audio.
    
    Uses spectral gating to preserve voice while removing:
    - Fan/AC noise
    - Traffic sounds
    - TV/radio in background
    """
    
    def __init__(self, sample_rate: int = SAMPLE_RATE):
        self.sample_rate = sample_rate
        self.noisereduce_available = False
        self._check_dependencies()
        
    def _check_dependencies(self):
        """Check for noise reduction library."""
        try:
            import noisereduce
            self.noisereduce_available = True
        except ImportError:
            pass
    
    def suppress(self, audio: np.ndarray, strength: float = 0.7) -> np.ndarray:
        """
        Suppress background noise in audio.
        
        Args:
            audio: Input audio (float32)
            strength: Noise reduction strength (0.0-1.0)
            
        Returns:
            Cleaned audio
        """
        if not self.noisereduce_available:
            # Fallback: simple high-pass filter to remove rumble
            return self._simple_filter(audio)
        
        import noisereduce as nr
        
        cleaned = nr.reduce_noise(
            y=audio,
            sr=self.sample_rate,
            prop_decrease=strength,
            stationary=False,  # Handles non-stationary noise better
            n_fft=512,
            hop_length=128
        )
        
        return cleaned.astype(np.float32)
    
    def _simple_filter(self, audio: np.ndarray) -> np.ndarray:
        """Simple high-pass filter fallback."""
        try:
            from scipy.signal import butter, filtfilt
            # Remove frequencies below 80Hz (rumble, AC hum)
            b, a = butter(4, 80 / (self.sample_rate / 2), btype='high')
            return filtfilt(b, a, audio).astype(np.float32)
        except ImportError:
            return audio


# =============================================================================
# SINGLE SPEAKER ISOLATION
# =============================================================================

class SpeakerIsolator:
    """
    Isolates the primary speaker (user) from other voices.
    
    Strategy:
    - User's voice is typically louder (closer to mic)
    - User speaks when recording is intentionally started
    - Background voices are softer and inconsistent
    - Uses spectral analysis to identify and suppress secondary speakers
    """
    
    def __init__(self, sample_rate: int = SAMPLE_RATE):
        self.sample_rate = sample_rate
        self.user_energy_baseline = None
        self.user_pitch_range = None  # (min_pitch, max_pitch) in Hz
        
    def calibrate_user(self, audio: np.ndarray):
        """
        Calibrate to user's voice level and pitch characteristics.
        
        Call this with a sample of the user speaking alone.
        """
        # Calculate energy profile of user's voice
        chunk_size = int(0.1 * self.sample_rate)
        energies = []
        pitches = []
        
        for i in range(0, len(audio) - chunk_size, chunk_size):
            chunk = audio[i:i + chunk_size]
            energy = np.sqrt(np.mean(chunk ** 2))
            if energy > 0.01:  # Only voiced parts
                energies.append(energy)
                # Estimate pitch using autocorrelation
                pitch = self._estimate_pitch(chunk)
                if pitch is not None:
                    pitches.append(pitch)
        
        if energies:
            self.user_energy_baseline = np.median(energies)
        
        if pitches:
            # User's typical pitch range (with some tolerance)
            self.user_pitch_range = (
                max(50, np.percentile(pitches, 10) - 30),
                min(400, np.percentile(pitches, 90) + 30)
            )
    
    def _estimate_pitch(self, chunk: np.ndarray) -> Optional[float]:
        """Estimate pitch using autocorrelation."""
        if len(chunk) < 256:
            return None
        
        try:
            # Simple autocorrelation pitch detection
            corr = np.correlate(chunk, chunk, mode='full')
            corr = corr[len(corr)//2:]
            
            # Find first peak after initial drop
            min_lag = int(self.sample_rate / 400)  # Max pitch 400 Hz
            max_lag = int(self.sample_rate / 50)   # Min pitch 50 Hz
            
            if max_lag > len(corr):
                return None
            
            # Find the first significant peak
            for i in range(min_lag, min(max_lag, len(corr) - 1)):
                if corr[i] > corr[i-1] and corr[i] > corr[i+1]:
                    if corr[i] > 0.3 * corr[0]:  # Must be significant
                        return self.sample_rate / i
            
            return None
        except:
            return None
    
    def isolate(self, audio: np.ndarray) -> np.ndarray:
        """
        Isolate primary speaker from audio using multiple techniques.
        
        Techniques used:
        1. Energy-based gating (quieter sounds reduced)
        2. Spectral gating (remove frequencies outside speech range)
        3. Pitch-based filtering (suppress voices with different pitch)
        4. Directional emphasis (assumes user is loudest/closest)
        
        Args:
            audio: Input audio
            
        Returns:
            Audio with primary speaker emphasized, background suppressed
        """
        if self.user_energy_baseline is None:
            # First run: assume user is primary speaker
            self.calibrate_user(audio)
        
        result = audio.copy()
        
        # Step 1: Spectral gating - emphasize speech frequencies
        result = self._spectral_gate(result)
        
        # Step 2: Energy-based gating with adaptive threshold
        result = self._energy_gate(result)
        
        # Step 3: Pitch-based filtering (if we have user pitch info)
        if self.user_pitch_range is not None:
            result = self._pitch_filter(result)
        
        # Step 4: Final cleanup - remove very quiet remnants
        result = self._final_cleanup(result)
        
        return result
    
    def _spectral_gate(self, audio: np.ndarray) -> np.ndarray:
        """Apply spectral gating to emphasize primary speech frequencies."""
        try:
            from scipy.signal import butter, filtfilt
            
            # Bandpass filter for typical speech (80-3500 Hz)
            # This removes very low rumbles and high-frequency noise
            nyquist = self.sample_rate / 2
            low = 80 / nyquist
            high = min(3500 / nyquist, 0.99)
            
            if low >= high:
                return audio
            
            b, a = butter(4, [low, high], btype='band')
            filtered = filtfilt(b, a, audio)
            
            # Blend with original to keep some naturalness
            return 0.7 * filtered + 0.3 * audio
        except Exception as e:
            return audio
    
    def _energy_gate(self, audio: np.ndarray) -> np.ndarray:
        """Energy-based gating to suppress quieter (background) voices."""
        chunk_size = int(0.03 * self.sample_rate)  # 30ms chunks (smaller for precision)
        result = audio.copy()
        
        # Calculate energy profile
        energies = []
        for i in range(0, len(audio) - chunk_size, chunk_size):
            energy = np.sqrt(np.mean(audio[i:i + chunk_size] ** 2))
            energies.append(energy)
        
        if not energies:
            return audio
        
        # Dynamic threshold based on the audio content
        median_energy = np.median(energies)
        threshold = max(
            median_energy * 0.4,  # At least 40% of median
            self.user_energy_baseline * 0.35 if self.user_energy_baseline else median_energy * 0.4
        )
        
        for idx, i in enumerate(range(0, len(audio) - chunk_size, chunk_size)):
            if idx < len(energies):
                chunk_energy = energies[idx]
                
                if chunk_energy < threshold:
                    # Soft suppression based on how far below threshold
                    suppression = max(0.05, (chunk_energy / threshold) ** 2)
                    result[i:i + chunk_size] *= suppression
        
        return result
    
    def _pitch_filter(self, audio: np.ndarray) -> np.ndarray:
        """Filter out audio segments with pitch outside user's range."""
        chunk_size = int(0.05 * self.sample_rate)  # 50ms chunks
        result = audio.copy()
        
        min_pitch, max_pitch = self.user_pitch_range
        
        for i in range(0, len(audio) - chunk_size, chunk_size):
            chunk = audio[i:i + chunk_size]
            chunk_energy = np.sqrt(np.mean(chunk ** 2))
            
            # Only check pitch for voiced segments
            if chunk_energy > 0.01:
                pitch = self._estimate_pitch(chunk)
                
                if pitch is not None:
                    # If pitch is way outside user's range, it's likely a different speaker
                    if pitch < min_pitch * 0.7 or pitch > max_pitch * 1.3:
                        # Suppress this segment significantly
                        result[i:i + chunk_size] *= 0.15
        
        return result
    
    def _final_cleanup(self, audio: np.ndarray) -> np.ndarray:
        """Final pass to remove very quiet remnants."""
        # Calculate RMS for noise floor estimation
        rms = np.sqrt(np.mean(audio ** 2))
        noise_floor = rms * 0.05
        
        # Soft-clip very quiet parts (likely residual background)
        mask = np.abs(audio) < noise_floor
        audio[mask] *= 0.1
        
        return audio


# =============================================================================
# FEATURE 1: PHRASE MEMORY
# =============================================================================

class PhraseMemory:
    """
    Local phrase memory for the user.
    
    Stores:
    - User's name
    - Frequently used phrases
    - Word/phrase corrections specific to this user
    
    This ensures repeated words are ALWAYS understood correctly,
    even if pronunciation varies day-to-day.
    
    All data is LOCAL ONLY. Never shared. Never uploaded.
    """
    
    def __init__(self, memory_path: Path = PHRASE_MEMORY_PATH):
        self.memory_path = memory_path
        
        # User profile
        self.user_name: str = ""
        
        # Phrase mappings: what Whisper hears → what user means
        # Higher priority than word-level corrections
        self.phrase_corrections: Dict[str, str] = {}
        
        # Frequently used phrases (for context awareness)
        self.frequent_phrases: List[str] = []
        
        # Proper names the user uses often
        self.known_names: Dict[str, str] = {}
        
        # Usage statistics (helps prioritize corrections)
        self.phrase_usage_count: Dict[str, int] = {}
        
        self._load()
    
    def _load(self):
        """Load phrase memory from disk."""
        if self.memory_path.exists():
            try:
                with open(self.memory_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                
                self.user_name = data.get("user_name", "")
                self.phrase_corrections = data.get("phrase_corrections", {})
                self.frequent_phrases = data.get("frequent_phrases", [])
                self.known_names = data.get("known_names", {})
                self.phrase_usage_count = data.get("phrase_usage_count", {})
            except:
                pass
    
    def _save(self):
        """Save phrase memory to disk."""
        self.memory_path.parent.mkdir(parents=True, exist_ok=True)
        
        data = {
            "user_name": self.user_name,
            "phrase_corrections": self.phrase_corrections,
            "frequent_phrases": self.frequent_phrases,
            "known_names": self.known_names,
            "phrase_usage_count": self.phrase_usage_count,
            "_note": "This is your personal phrase memory. Local only. Never shared."
        }
        
        with open(self.memory_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
    
    def set_user_name(self, name: str):
        """Set the user's name."""
        self.user_name = name.strip()
        self._save()
    
    def add_phrase_correction(self, heard: str, intended: str):
        """
        Add a phrase-level correction.
        
        Example: "Monroe" → "Emmanuel"
        """
        heard_lower = heard.lower().strip()
        intended_clean = intended.strip()
        
        if heard_lower and intended_clean:
            self.phrase_corrections[heard_lower] = intended_clean
            self._save()
    
    def add_name(self, heard: str, correct_name: str):
        """
        Add a proper name correction.
        
        Names are given highest priority in normalization.
        """
        heard_lower = heard.lower().strip()
        correct = correct_name.strip()
        
        if heard_lower and correct:
            self.known_names[heard_lower] = correct
            self._save()
    
    def add_frequent_phrase(self, phrase: str):
        """Add a phrase the user uses often."""
        phrase_clean = phrase.strip()
        if phrase_clean and phrase_clean not in self.frequent_phrases:
            self.frequent_phrases.append(phrase_clean)
            self._save()
    
    def record_usage(self, phrase: str):
        """Record that a phrase was used (for learning)."""
        phrase_lower = phrase.lower().strip()
        self.phrase_usage_count[phrase_lower] = self.phrase_usage_count.get(phrase_lower, 0) + 1
        # Save periodically (every 10 uses)
        if sum(self.phrase_usage_count.values()) % 10 == 0:
            self._save()
    
    def apply_corrections(self, text: str) -> str:
        """
        Apply phrase memory corrections to text.
        
        Priority order:
        1. Known names (highest)
        2. Phrase corrections
        3. Original text (if no match)
        
        This runs BEFORE word-level normalization.
        """
        if not text:
            return text
        
        result = text
        
        # Apply name corrections (case-insensitive matching, preserve intended case)
        for heard, correct in self.known_names.items():
            # Case-insensitive replacement
            import re
            pattern = re.compile(re.escape(heard), re.IGNORECASE)
            result = pattern.sub(correct, result)
        
        # Apply phrase corrections
        for heard, intended in self.phrase_corrections.items():
            import re
            pattern = re.compile(re.escape(heard), re.IGNORECASE)
            result = pattern.sub(intended, result)
        
        # Track usage
        self.record_usage(result)
        
        return result
    
    def get_summary(self) -> str:
        """Get a summary of stored memory."""
        lines = []
        if self.user_name:
            lines.append(f"User: {self.user_name}")
        lines.append(f"Name corrections: {len(self.known_names)}")
        lines.append(f"Phrase corrections: {len(self.phrase_corrections)}")
        lines.append(f"Frequent phrases: {len(self.frequent_phrases)}")
        return "\n".join(lines)


# =============================================================================
# TEXT NORMALIZATION (Pronunciation Correction)
# =============================================================================

class PronunciationNormalizer:
    """
    Silently corrects pronunciation in transcribed text.
    
    IMPORTANT: This is NOT about correcting the user.
    This is about ensuring the OUTPUT sounds correct.
    
    The user's words are understood and respected.
    Only the public-facing speech is normalized.
    """
    
    def __init__(self, memory_path: Path = USER_MEMORY_PATH):
        self.memory_path = memory_path
        
        # User-specific word mappings (learned over time)
        # Maps user's typical transcription → intended word
        self.user_word_memory: Dict[str, str] = {}
        
        # Common phonetic confusions for unclear speech
        # These are patterns Whisper might produce
        self.phonetic_corrections = {
            # Common consonant confusions (th sounds)
            "dis": "this",
            "dat": "that",
            "dey": "they",
            "dem": "them",
            "der": "there",
            "dere": "there",
            "dese": "these",
            "dose": "those",
            "wif": "with",
            "wiv": "with",
            "nuffin": "nothing",
            "nufin": "nothing",
            "somefing": "something",
            "somefin": "something",
            "anyfing": "anything",
            "anyfin": "anything",
            "everyfing": "everything",
            "fink": "think",
            "finks": "thinks",
            "fought": "thought",
            "frow": "throw",
            "free": "three",  # context-dependent but common
            "frough": "through",
            "brudder": "brother",
            "mudder": "mother",
            "fadder": "father",
            "bruvver": "brother",
            "muvver": "mother",
            "favver": "father",
            
            # R and L confusions
            "wight": "right",
            "weally": "really",
            "wun": "run",
            "wed": "red",
            "wice": "rice",
            "pwease": "please",
            "pway": "play",
            "fwiend": "friend",
            "cwy": "cry",
            "bwing": "bring",
            
            # S and SH confusions
            "sip": "ship",
            "seep": "sheep",
            "sore": "shore",
            "sow": "show",
            
            # Vowel clarity issues
            "becuz": "because",
            "becoz": "because",
            "cuz": "because",
            "coz": "because",
            "gonna": "going to",
            "wanna": "want to",
            "gotta": "got to",
            "kinda": "kind of",
            "sorta": "sort of",
            "outta": "out of",
            "coulda": "could have",
            "woulda": "would have",
            "shoulda": "should have",
            "mighta": "might have",
            "musta": "must have",
            "oughta": "ought to",
            "hafta": "have to",
            "hasta": "has to",
            "useta": "used to",
            "supposta": "supposed to",
            "spose": "suppose",
            "prolly": "probably",
            "probly": "probably",
            
            # Common unclear endings
            "walkin": "walking",
            "talkin": "talking",
            "runnin": "running",
            "comin": "coming",
            "goin": "going",
            "doin": "doing",
            "sayin": "saying",
            "playin": "playing",
            "workin": "working",
            "thinkin": "thinking",
            "lookin": "looking",
            "tryin": "trying",
            "buyin": "buying",
            "flyin": "flying",
            "cryin": "crying",
            "lyin": "lying",
            
            # Word blends and slurring
            "lemme": "let me",
            "gimme": "give me",
            "whatcha": "what are you",
            "gotcha": "got you",
            "betcha": "bet you",
            "doncha": "don't you",
            "didja": "did you",
            "wouldja": "would you",
            "couldja": "could you",
            "shouldja": "should you",
            "howja": "how did you",
            "whyja": "why did you",
            "whereya": "where are you",
            "howya": "how are you",
            "whataya": "what are you",
            "dunno": "don't know",
            "duno": "don't know",
            "iono": "I don't know",
            "idunno": "I don't know",
            "imma": "I'm going to",
            "ima": "I'm going to",
            "ain't": "am not",
            "aint": "am not",
            "innit": "isn't it",
            "init": "isn't it",
            "y'all": "you all",
            "yall": "you all",
            
            # Common mispronunciations
            "libary": "library",
            "liberry": "library",
            "febuary": "february",
            "supposably": "supposedly",
            "expresso": "espresso",
            "excape": "escape",
            "excapegoat": "scapegoat",
            "axe": "ask",
            "aks": "ask",
            "ast": "asked",
            "nucular": "nuclear",
            "athalete": "athlete",
            "heighth": "height",
            "pronounciation": "pronunciation",
            "mischievious": "mischievous",
            "perscription": "prescription",
            "supposively": "supposedly",
            "expecially": "especially",
            "pacific": "specific",
            "irregardless": "regardless",
            "conversate": "converse",
            "orientate": "orient",
            
            # ============================================
            # NUMBERS - spoken forms and confusions
            # ============================================
            # Basic numbers (mispronunciations)
            "wun": "one",
            "too": "two",
            "tu": "two",
            "tree": "three",
            "fo": "four",
            "foh": "four",
            "fiv": "five",
            "siks": "six",
            "secks": "six",
            "seben": "seven",
            "sebben": "seven",
            "ate": "eight",
            "eit": "eight",
            "nein": "nine",
            "nin": "nine",
            "tenn": "ten",
            "leben": "eleven",
            "eleben": "eleven",
            "twelf": "twelve",
            "twelv": "twelve",
            "tirteen": "thirteen",
            "forteen": "fourteen",
            "fiften": "fifteen",
            "sikteen": "sixteen",
            "sebteen": "seventeen",
            "eiteen": "eighteen",
            "ninteen": "nineteen",
            "twenny": "twenty",
            "tweny": "twenty",
            "tirty": "thirty",
            "thurty": "thirty",
            "fourty": "forty",
            "foty": "forty",
            "fiddy": "fifty",
            "fifdy": "fifty",
            "sikty": "sixty",
            "sebenty": "seventy",
            "eity": "eighty",
            "ninedy": "ninety",
            "hunnerd": "hundred",
            "hunnred": "hundred",
            "hunderd": "hundred",
            "tousand": "thousand",
            "thousan": "thousand",
            "millon": "million",
            "milion": "million",
            "billon": "billion",
            "bilion": "billion",
            
            # Ordinal numbers
            "firs": "first",
            "furst": "first",
            "secund": "second",
            "secon": "second",
            "tird": "third",
            "thurd": "third",
            "fort": "fourth",
            "fith": "fifth",
            "sixt": "sixth",
            "sevent": "seventh",
            "eigt": "eighth",
            "nint": "ninth",
            "tent": "tenth",
            
            # ============================================
            # DAYS OF THE WEEK
            # ============================================
            "munday": "monday",
            "mondey": "monday",
            "tooesday": "tuesday",
            "tusday": "tuesday",
            "wensday": "wednesday",
            "wendsday": "wednesday",
            "wendesday": "wednesday",
            "thursdy": "thursday",
            "thrusday": "thursday",
            "frieday": "friday",
            "fridy": "friday",
            "saterday": "saturday",
            "satday": "saturday",
            "sundey": "sunday",
            "sundy": "sunday",
            
            # ============================================
            # MONTHS OF THE YEAR
            # ============================================
            "januery": "january",
            "janurary": "january",
            "febrary": "february",
            "feburary": "february",
            "febuary": "february",
            "marcg": "march",
            "apirl": "april",
            "aperil": "april",
            "mai": "may",
            "joon": "june",
            "julai": "july",
            "julei": "july",
            "augus": "august",
            "agust": "august",
            "septembr": "september",
            "setember": "september",
            "octobr": "october",
            "ocotber": "october",
            "novembr": "november",
            "novemba": "november",
            "decembr": "december",
            "decemba": "december",
            
            # ============================================
            # TIME EXPRESSIONS
            # ============================================
            "oclock": "o'clock",
            "o'clok": "o'clock",
            "oclok": "o'clock",
            "minit": "minute",
            "minuts": "minutes",
            "minits": "minutes",
            "secund": "second",
            "secunds": "seconds",
            "sekonds": "seconds",
            "owa": "hour",
            "owrs": "hours",
            "ours": "hours",
            "mornin": "morning",
            "moning": "morning",
            "aftanoon": "afternoon",
            "aftenoon": "afternoon",
            "evenin": "evening",
            "evning": "evening",
            "tonite": "tonight",
            "tonigt": "tonight",
            "tomorro": "tomorrow",
            "tomorow": "tomorrow",
            "tommorow": "tomorrow",
            "yestaday": "yesterday",
            "yesturday": "yesterday",
            "yestoday": "yesterday",
            
            # ============================================
            # GREETINGS AND COMMON PHRASES
            # ============================================
            "helo": "hello",
            "helllo": "hello",
            "hallo": "hello",
            "hai": "hi",
            "heya": "hey",
            "hiya": "hi there",
            "gmorning": "good morning",
            "gnight": "good night",
            "gudnite": "good night",
            "gudnight": "good night",
            "bai": "bye",
            "baibai": "bye bye",
            "byebye": "bye bye",
            "seya": "see you",
            "seeya": "see you",
            "cya": "see you",
            "lata": "later",
            "latr": "later",
            "laterz": "later",
            "tanks": "thanks",
            "thnks": "thanks",
            "thankz": "thanks",
            "thanku": "thank you",
            "thnx": "thanks",
            "plez": "please",
            "plz": "please",
            "pleas": "please",
            "welcom": "welcome",
            "welcum": "welcome",
            "yor welcom": "you're welcome",
            "ur welcom": "you're welcome",
            "sory": "sorry",
            "sorri": "sorry",
            "soory": "sorry",
            "excuz": "excuse",
            "scuse": "excuse",
            "xcuse": "excuse",
            
            # ============================================
            # COMMON CONVERSATION WORDS
            # ============================================
            # Questions
            "wat": "what",
            "wot": "what",
            "wen": "when",
            "wher": "where",
            "whre": "where",
            "wy": "why",
            "hao": "how",
            "hau": "how",
            "wich": "which",
            "hoo": "who",
            "hu": "who",
            "hoom": "whom",
            
            # Pronouns
            "i'm": "I'm",
            "im": "I'm",
            "i'll": "I'll",
            "ill": "I'll",
            "i've": "I've",
            "ive": "I've",
            "i'd": "I'd",
            "id": "I'd",
            "yoo": "you",
            "yu": "you",
            "u": "you",
            "ur": "your",
            "yor": "your",
            "youre": "you're",
            "yur": "you're",
            "hee": "he",
            "shee": "she",
            "wee": "we",
            "thay": "they",
            "ther": "their",
            "thier": "their",
            "theyre": "they're",
            "theres": "there's",
            "hes": "he's",
            "shes": "she's",
            "weve": "we've",
            "theyve": "they've",
            "itll": "it'll",
            "its": "it's",
            "itz": "it's",
            
            # Verbs - be
            "iz": "is",
            "ar": "are",
            "waz": "was",
            "wuz": "was",
            "wer": "were",
            "wur": "were",
            "bin": "been",
            "ben": "been",
            "bein": "being",
            
            # Verbs - have
            "hav": "have",
            "haz": "has",
            "havin": "having",
            "hadnt": "hadn't",
            "hasnt": "hasn't",
            "havent": "haven't",
            
            # Verbs - do
            "doo": "do",
            "duz": "does",
            "didnt": "didn't",
            "doesnt": "doesn't",
            "dont": "don't",
            
            # Verbs - can/will/would
            "kan": "can",
            "cud": "could",
            "cant": "can't",
            "carnt": "can't",
            "couldnt": "couldn't",
            "wil": "will",
            "wont": "won't",
            "wouldnt": "wouldn't",
            "shud": "should",
            "shouldnt": "shouldn't",
            "shal": "shall",
            
            # Common verbs
            "noe": "know",
            "no": "know",  # context needed but common
            "kno": "know",
            "knw": "know",
            "nown": "known",
            "sea": "see",
            "c": "see",
            "saw": "saw",
            "sean": "seen",
            "seein": "seeing",
            "heer": "hear",
            "herd": "heard",
            "hearin": "hearing",
            "sai": "say",
            "sed": "said",
            "sayin": "saying",
            "tel": "tell",
            "tol": "told",
            "tellin": "telling",
            "giv": "give",
            "gav": "gave",
            "givin": "giving",
            "giben": "given",
            "tak": "take",
            "tuk": "took",
            "takin": "taking",
            "takan": "taken",
            "mak": "make",
            "mad": "made",
            "makin": "making",
            "git": "get",
            "gat": "got",
            "gettin": "getting",
            "gotin": "gotten",
            "cum": "come",
            "cam": "came",
            "comin": "coming",
            "goe": "go",
            "gos": "goes",
            "wen": "went",
            "gon": "gone",
            "brin": "bring",
            "brot": "brought",
            "bringin": "bringing",
            "fyn": "find",
            "foun": "found",
            "findin": "finding",
            "tri": "try",
            "traid": "tried",
            "tryin": "trying",
            "wach": "watch",
            "wachd": "watched",
            "watchin": "watching",
            "lisn": "listen",
            "lisend": "listened",
            "lisnin": "listening",
            "rememba": "remember",
            "remembr": "remember",
            "remeber": "remember",
            "rember": "remember",
            "undastand": "understand",
            "understan": "understand",
            "undrstand": "understand",
            
            # ============================================
            # COMMON ADJECTIVES
            # ============================================
            "gud": "good",
            "goud": "good",
            "gret": "great",
            "grate": "great",
            "nise": "nice",
            "nic": "nice",
            "bad": "bad",
            "baad": "bad",
            "beter": "better",
            "bettr": "better",
            "bes": "best",
            "bst": "best",
            "wors": "worse",
            "wrse": "worse",
            "wurst": "worst",
            "wrst": "worst",
            "big": "big",
            "bigg": "big",
            "smal": "small",
            "smol": "small",
            "larg": "large",
            "larj": "large",
            "littl": "little",
            "litle": "little",
            "yung": "young",
            "yong": "young",
            "ol": "old",
            "olde": "old",
            "nu": "new",
            "noo": "new",
            "hapi": "happy",
            "hapy": "happy",
            "sad": "sad",
            "saad": "sad",
            "angri": "angry",
            "angy": "angry",
            "tird": "tired",
            "tierd": "tired",
            "sik": "sick",
            "sic": "sick",
            "helthy": "healthy",
            "helfy": "healthy",
            "stron": "strong",
            "strng": "strong",
            "wek": "weak",
            "wik": "weak",
            "fas": "fast",
            "fst": "fast",
            "slo": "slow",
            "sloe": "slow",
            "quik": "quick",
            "qick": "quick",
            "esy": "easy",
            "eazy": "easy",
            "hrd": "hard",
            "harrd": "hard",
            "difrent": "different",
            "diffrent": "different",
            "differnt": "different",
            "sam": "same",
            "saim": "same",
            "impotant": "important",
            "importnt": "important",
            "intresting": "interesting",
            "interestin": "interesting",
            "beautful": "beautiful",
            "beautifull": "beautiful",
            "butifl": "beautiful",
            "wunderful": "wonderful",
            "wonderfl": "wonderful",
            "amazin": "amazing",
            "amaizing": "amazing",
            "awsum": "awesome",
            "awsom": "awesome",
            "terble": "terrible",
            "terible": "terrible",
            "horible": "horrible",
            "horrable": "horrible",
            
            # ============================================
            # COMMON ADVERBS
            # ============================================
            "realy": "really",
            "relly": "really",
            "vry": "very",
            "veri": "very",
            "too": "too",
            "allso": "also",
            "alwys": "always",
            "allways": "always",
            "nevr": "never",
            "neva": "never",
            "sumtimes": "sometimes",
            "sumtims": "sometimes",
            "usualy": "usually",
            "usuallly": "usually",
            "probly": "probably",
            "prolly": "probably",
            "definetly": "definitely",
            "definately": "definitely",
            "definitly": "definitely",
            "actualy": "actually",
            "actuall": "actually",
            "basicly": "basically",
            "basicaly": "basically",
            "especialy": "especially",
            "espeshally": "especially",
            "finaly": "finally",
            "finially": "finally",
            "naturaly": "naturally",
            "naturly": "naturally",
            "certanly": "certainly",
            "certnly": "certainly",
            "obviosly": "obviously",
            "obviusly": "obviously",
            
            # ============================================
            # COMMON NOUNS
            # ============================================
            # People
            "peeple": "people",
            "peopl": "people",
            "persn": "person",
            "purson": "person",
            "frend": "friend",
            "freind": "friend",
            "frends": "friends",
            "famly": "family",
            "fambly": "family",
            "famili": "family",
            "chilren": "children",
            "childrin": "children",
            "chidren": "children",
            "parens": "parents",
            "parints": "parents",
            "bruther": "brother",
            "brotha": "brother",
            "sistor": "sister",
            "sista": "sister",
            "docter": "doctor",
            "docta": "doctor",
            "techer": "teacher",
            "teacha": "teacher",
            
            # Places
            "hom": "home",
            "hoam": "home",
            "hous": "house",
            "howse": "house",
            "scool": "school",
            "skool": "school",
            "offise": "office",
            "ofice": "office",
            "hosptal": "hospital",
            "hospitl": "hospital",
            "stoar": "store",
            "stor": "store",
            "restrant": "restaurant",
            "restarant": "restaurant",
            "restraunt": "restaurant",
            
            # Things
            "fone": "phone",
            "fon": "phone",
            "computa": "computer",
            "computr": "computer",
            "computor": "computer",
            "mony": "money",
            "munny": "money",
            "monei": "money",
            "watur": "water",
            "watr": "water",
            "fud": "food",
            "foud": "food",
            "kar": "car",
            "carr": "car",
            "buk": "book",
            "buks": "books",
            
            # ============================================
            # CONNECTORS AND PREPOSITIONS
            # ============================================
            "an": "and",
            "nd": "and",
            "ore": "or",
            "butt": "but",
            "bt": "but",
            "becuz": "because",
            "cuz": "because",
            "coz": "because",
            "bcuz": "because",
            "soe": "so",
            "tho": "though",
            "altho": "although",
            "althou": "although",
            "howeva": "however",
            "howevr": "however",
            "therfor": "therefore",
            "therefor": "therefore",
            "too": "to",
            "frum": "from",
            "frm": "from",
            "wit": "with",
            "wif": "with",
            "witout": "without",
            "wifout": "without",
            "abowt": "about",
            "abot": "about",
            "befor": "before",
            "b4": "before",
            "aftr": "after",
            "afta": "after",
            "durin": "during",
            "durng": "during",
            "beetween": "between",
            "betwean": "between",
            "agenst": "against",
            "agains": "against",
            "thro": "through",
            "throu": "through",
            "untl": "until",
            "untill": "until",
            "sinse": "since",
            "sins": "since",
            
            # ============================================
            # COMMON PHRASES (multi-word)
            # ============================================
            "alotta": "a lot of",
            "lotsa": "lots of",
            "kindof": "kind of",
            "sortof": "sort of",
            "insteadof": "instead of",
            "inspiteof": "in spite of",
            "becauseof": "because of",
            "infront": "in front",
            "alright": "all right",
            "aright": "all right",
            "alltogether": "all together",
            "eachother": "each other",
            "everyting": "everything",
            "evrything": "everything",
            "somting": "something",
            "sumthing": "something",
            "anyting": "anything",
            "anythin": "anything",
            "noting": "nothing",
            "nuffin": "nothing",
            "everwhere": "everywhere",
            "everywher": "everywhere",
            "somewere": "somewhere",
            "somwhere": "somewhere",
            "anywere": "anywhere",
            "anywher": "anywhere",
            "nowere": "nowhere",
            "nowher": "nowhere",
            "evryone": "everyone",
            "everbody": "everybody",
            "somone": "someone",
            "sumbody": "somebody",
            "anyon": "anyone",
            "anybdy": "anybody",
            "noon": "no one",
            "nobdy": "nobody",
            
            # ============================================
            # TECHNOLOGY AND MODERN WORDS
            # ============================================
            "intanet": "internet",
            "internett": "internet",
            "websit": "website",
            "websight": "website",
            "emal": "email",
            "e-mal": "email",
            "mesage": "message",
            "messag": "message",
            "pasword": "password",
            "passwrd": "password",
            "downlod": "download",
            "downlowd": "download",
            "uplod": "upload",
            "uplowd": "upload",
            "softwear": "software",
            "softwere": "software",
            "hardwear": "hardware",
            "hardwere": "hardware",
            "batry": "battery",
            "battry": "battery",
            "charjer": "charger",
            "chargr": "charger",
            "screan": "screen",
            "scren": "screen",
            "keybord": "keyboard",
            "keebord": "keyboard",
            
            # ============================================
            # FOOD AND DRINKS
            # ============================================
            "brekfast": "breakfast",
            "brekfist": "breakfast",
            "lnch": "lunch",
            "lunsh": "lunch",
            "dinnr": "dinner",
            "dinnar": "dinner",
            "coffe": "coffee",
            "cofee": "coffee",
            "tee": "tea",
            "juise": "juice",
            "joos": "juice",
            "bred": "bread",
            "brd": "bread",
            "chese": "cheese",
            "cheez": "cheese",
            "chiken": "chicken",
            "chickin": "chicken",
            "vegetbles": "vegetables",
            "vegtables": "vegetables",
            "frut": "fruit",
            "froot": "fruit",
            
            # ============================================
            # WEATHER
            # ============================================
            "wether": "weather",
            "wheather": "weather",
            "suny": "sunny",
            "suni": "sunny",
            "cloudi": "cloudy",
            "cloudey": "cloudy",
            "raini": "rainy",
            "rainey": "rainy",
            "snowi": "snowy",
            "snowey": "snowy",
            "windi": "windy",
            "windey": "windy",
            "coald": "cold",
            "colde": "cold",
            "hott": "hot",
            "warme": "warm",
            "worm": "warm",
            
            # ============================================
            # BODY PARTS
            # ============================================
            "hed": "head",
            "hedd": "head",
            "fase": "face",
            "fays": "face",
            "i's": "eyes",
            "eys": "eyes",
            "eers": "ears",
            "earrs": "ears",
            "noze": "nose",
            "noz": "nose",
            "mouf": "mouth",
            "mowth": "mouth",
            "teth": "teeth",
            "teef": "teeth",
            "hart": "heart",
            "hrt": "heart",
            "stomak": "stomach",
            "stomack": "stomach",
            "bak": "back",
            "bakk": "back",
            "leg": "leg",
            "legg": "leg",
            "fut": "foot",
            "fot": "foot",
            "fet": "feet",
            "feets": "feet",
            "hnad": "hand",
            "hnd": "hand",
            "fingr": "finger",
            "fingur": "finger",
            
            # ============================================
            # COLORS
            # ============================================
            "wite": "white",
            "whit": "white",
            "blak": "black",
            "blck": "black",
            "blu": "blue",
            "bloo": "blue",
            "gren": "green",
            "grean": "green",
            "yelo": "yellow",
            "yelow": "yellow",
            "orang": "orange",
            "ornge": "orange",
            "purpl": "purple",
            "purpel": "purple",
            "pnk": "pink",
            "pinc": "pink",
            "braun": "brown",
            "brwn": "brown",
            "grei": "gray",
            "gry": "gray",
            
            # ============================================
            # EMOTIONS AND FEELINGS
            # ============================================
            "happi": "happy",
            "hapy": "happy",
            "sadd": "sad",
            "angree": "angry",
            "angrry": "angry",
            "scarred": "scared",
            "scaired": "scared",
            "exited": "excited",
            "excted": "excited",
            "nervus": "nervous",
            "nervos": "nervous",
            "worred": "worried",
            "woried": "worried",
            "confuzed": "confused",
            "confusd": "confused",
            "surprized": "surprised",
            "surprisd": "surprised",
            "disapointed": "disappointed",
            "dissapointed": "disappointed",
            "embarased": "embarrassed",
            "embarrased": "embarrassed",
            "jelous": "jealous",
            "jelus": "jealous",
            "prowd": "proud",
            "praud": "proud",
            "releved": "relieved",
            "releeved": "relieved",
        }
        
        # Load user-specific memory
        self._load_memory()
    
    def _load_memory(self):
        """Load user's word preference memory."""
        if self.memory_path.exists():
            try:
                with open(self.memory_path, 'r') as f:
                    self.user_word_memory = json.load(f)
            except:
                pass
    
    def _save_memory(self):
        """Save user's word preference memory."""
        self.memory_path.parent.mkdir(parents=True, exist_ok=True)
        with open(self.memory_path, 'w') as f:
            json.dump(self.user_word_memory, f, indent=2)
    
    def learn_correction(self, heard: str, intended: str):
        """
        Learn a user-specific correction.
        
        Call this when user indicates what they meant.
        This builds personalized understanding over time.
        """
        heard_lower = heard.lower().strip()
        intended_clean = intended.strip()
        
        if heard_lower and intended_clean:
            self.user_word_memory[heard_lower] = intended_clean
            self._save_memory()
    
    def normalize(self, text: str) -> str:
        """
        Normalize text for clear pronunciation on output.
        
        This does NOT change meaning - only ensures clarity.
        
        Args:
            text: Raw transcribed text from Whisper
            
        Returns:
            Normalized text ready for TTS
        """
        if not text:
            return text
        
        words = text.split()
        normalized_words = []
        
        for word in words:
            # Preserve original case pattern
            was_capitalized = word[0].isupper() if word else False
            was_all_caps = word.isupper() if len(word) > 1 else False
            
            word_lower = word.lower()
            
            # Strip punctuation for matching
            punctuation = ''
            if word_lower and word_lower[-1] in '.,!?;:':
                punctuation = word_lower[-1]
                word_lower = word_lower[:-1]
            
            # Check user's personal memory first (highest priority)
            if word_lower in self.user_word_memory:
                normalized = self.user_word_memory[word_lower]
            # Then check common phonetic corrections
            elif word_lower in self.phonetic_corrections:
                normalized = self.phonetic_corrections[word_lower]
            else:
                normalized = word_lower
            
            # Restore case pattern
            if was_all_caps:
                normalized = normalized.upper()
            elif was_capitalized:
                normalized = normalized.capitalize()
            
            # Restore punctuation
            normalized_words.append(normalized + punctuation)
        
        return ' '.join(normalized_words)
    
    def get_corrections_applied(self, original: str, normalized: str) -> List[Tuple[str, str]]:
        """
        Get list of corrections that were applied (for logging only, not shown to user).
        """
        corrections = []
        orig_words = original.lower().split()
        norm_words = normalized.lower().split()
        
        for o, n in zip(orig_words, norm_words):
            o_clean = o.rstrip('.,!?;:')
            n_clean = n.rstrip('.,!?;:')
            if o_clean != n_clean:
                corrections.append((o_clean, n_clean))
        
        return corrections


# =============================================================================
# MAIN PIPELINE
# =============================================================================

class DenuelVoiceBridge:
    """
    DENUEL VOICE BRIDGE - Main Processing Pipeline
    
    Listens to user → Understands intent → Outputs clear speech
    
    The user's dignity and confidence are protected at all times.
    """
    
    def __init__(self, voice_sample_path: str = None):
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        print(f"🖥️  Device: {self.device}")
        
        # Processing components
        self.vad = VoiceActivityDetector()
        self.noise_suppressor = NoiseSuppressor()
        self.speaker_isolator = SpeakerIsolator()
        self.normalizer = PronunciationNormalizer()
        self.phrase_memory = PhraseMemory()  # FEATURE 1: Phrase Memory
        
        # Models (lazy loaded)
        self.whisper_model = None
        self.tts_model = None
        
        # User's voice profile
        self.voice_sample_path = voice_sample_path
        
        # State
        self.last_input_text = None
        self.last_output_text = None
        self.last_audio_output = None
        
        # Live mode state
        self._live_mode_active = False
        self._stop_requested = False
        
        # Ensure directories exist
        OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        
    # -------------------------------------------------------------------------
    # MODEL LOADING
    # -------------------------------------------------------------------------
    
    def load_whisper(self):
        """Load Whisper for speech recognition."""
        if self.whisper_model is not None:
            return
        
        print("📥 Loading speech recognition...")
        import whisper
        # Use 'small' for better accuracy with unclear speech
        self.whisper_model = whisper.load_model("small", device=self.device)
        print("✅ Ready to listen!")
    
    def load_tts(self):
        """Load XTTS for voice synthesis."""
        if self.tts_model is not None:
            return
        
        print("📥 Loading voice synthesis...")
        os.environ["COQUI_TOS_AGREED"] = "1"
        
        from TTS.api import TTS
        self.tts_model = TTS("tts_models/multilingual/multi-dataset/xtts_v2").to(self.device)
        print("✅ Ready to speak!")
    
    # -------------------------------------------------------------------------
    # AUDIO INPUT (Private - User's voice)
    # -------------------------------------------------------------------------
    
    def record_until_silence(self, max_duration: float = 30.0) -> np.ndarray:
        """
        Record audio until user stops speaking.
        
        Uses VAD to detect natural end of speech.
        Never interrupts the user.
        """
        print("🎤 Listening... (speak naturally)")
        
        chunk_samples = int(CHUNK_DURATION * SAMPLE_RATE)
        max_samples = int(max_duration * SAMPLE_RATE)
        
        audio_buffer = []
        total_samples = 0
        speech_started = False
        silence_after_speech = 0
        
        self.vad.reset()
        
        def audio_callback(indata, frames, time_info, status):
            nonlocal speech_started, silence_after_speech
            
            chunk = indata[:, 0].copy()
            is_speech = self.vad.process_chunk(chunk)
            
            if is_speech:
                speech_started = True
                silence_after_speech = 0
            elif speech_started:
                silence_after_speech += 1
            
            audio_buffer.append(chunk)
        
        # Start recording
        with sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=CHANNELS,
            dtype='float32',
            blocksize=chunk_samples,
            callback=audio_callback
        ):
            # Wait for speech to start and end
            while total_samples < max_samples:
                time.sleep(0.1)
                total_samples = len(audio_buffer) * chunk_samples
                
                # Stop after sustained silence following speech
                if speech_started and silence_after_speech > 15:  # ~1.5s silence
                    break
        
        if not audio_buffer:
            return np.array([], dtype=np.float32)
        
        audio = np.concatenate(audio_buffer)
        print(f"✅ Captured {len(audio) / SAMPLE_RATE:.1f}s of audio")
        
        return audio
    
    def record_fixed_duration(self, duration: float = 5.0) -> np.ndarray:
        """Record for a fixed duration."""
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
    
    # -------------------------------------------------------------------------
    # AUDIO PROCESSING (Private - Clean the input)
    # -------------------------------------------------------------------------
    
    def clean_audio(self, audio: np.ndarray, aggressive: bool = True) -> np.ndarray:
        """
        Clean audio: suppress noise and isolate user's voice.
        
        This ensures we only process what the USER said,
        not background noise or other voices.
        
        Args:
            audio: Input audio array
            aggressive: If True, more aggressively suppress background voices
        """
        if len(audio) == 0:
            return audio
        
        # Step 1: Remove background noise (stronger reduction)
        cleaned = self.noise_suppressor.suppress(audio, strength=0.85 if aggressive else 0.7)
        
        # Step 2: Isolate primary speaker (user)
        cleaned = self.speaker_isolator.isolate(cleaned)
        
        # Step 3: If aggressive, apply secondary pass for stubborn background voices
        if aggressive:
            cleaned = self._aggressive_voice_isolation(cleaned)
        
        return cleaned
    
    def _aggressive_voice_isolation(self, audio: np.ndarray) -> np.ndarray:
        """
        Additional aggressive filtering to remove residual background voices.
        
        This is for cases where there are persistent background talkers.
        """
        try:
            # Re-estimate energy after first pass
            chunk_size = int(0.02 * SAMPLE_RATE)  # 20ms chunks
            result = audio.copy()
            
            # Get the loudest segments (likely the user)
            energies = []
            for i in range(0, len(audio) - chunk_size, chunk_size):
                energy = np.sqrt(np.mean(audio[i:i + chunk_size] ** 2))
                energies.append(energy)
            
            if not energies:
                return audio
            
            # User is likely in the top percentile of energy
            user_energy_threshold = np.percentile(energies, 70)
            
            # Suppress anything significantly quieter
            for idx, i in enumerate(range(0, len(audio) - chunk_size, chunk_size)):
                if idx < len(energies):
                    if energies[idx] < user_energy_threshold * 0.4:
                        # Very aggressive suppression for quiet parts
                        result[i:i + chunk_size] *= 0.05
                    elif energies[idx] < user_energy_threshold * 0.6:
                        # Moderate suppression
                        result[i:i + chunk_size] *= 0.3
            
            return result
        except Exception as e:
            return audio
    
    # -------------------------------------------------------------------------
    # SPEECH UNDERSTANDING (Private - What did user mean?)
    # -------------------------------------------------------------------------
    
    def understand(self, audio: np.ndarray) -> str:
        """
        Understand what the user intended to say.
        
        Uses Whisper with settings optimized for unclear speech.
        """
        self.load_whisper()
        
        if len(audio) == 0:
            return ""
        
        print("🧠 Understanding...")
        
        # Whisper transcription with best-effort settings
        result = self.whisper_model.transcribe(
            audio,
            language="en",
            fp16=(self.device == "cuda"),
            # These settings help with unclear speech:
            temperature=0.0,  # Deterministic output
            compression_ratio_threshold=2.4,
            logprob_threshold=-1.0,
            no_speech_threshold=0.6,
        )
        
        text = result["text"].strip()
        self.last_input_text = text
        
        if text:
            print(f"   Heard: \"{text}\"")
        
        return text
    
    # -------------------------------------------------------------------------
    # OUTPUT GENERATION (Public - Clear speech)
    # -------------------------------------------------------------------------
    
    def generate_clear_speech(self, text: str, save: bool = False) -> np.ndarray:
        """
        Generate clear, correctly-pronounced speech.
        
        The output:
        - Sounds like the USER
        - Has correct pronunciation
        - Preserves the user's meaning exactly
        
        Normalization order:
        1. Phrase memory (names, phrases) - highest priority
        2. Word-level normalization (phonetic corrections)
        """
        self.load_tts()
        
        if not text:
            return None
        
        # STEP 1: Apply phrase memory corrections FIRST (Feature 1)
        # This handles names and specific phrases the user has taught
        phrase_corrected = self.phrase_memory.apply_corrections(text)
        
        # STEP 2: Apply word-level pronunciation normalization
        normalized_text = self.normalizer.normalize(phrase_corrected)
        self.last_output_text = normalized_text
        
        # Log corrections (internal only, never shown to user)
        corrections = self.normalizer.get_corrections_applied(text, normalized_text)
        if corrections:
            # Silent internal logging
            pass
        
        print("🔊 Generating clear version...")
        
        # Get user's voice sample
        voice_sample = self._get_voice_sample()
        
        if voice_sample:
            # Generate with user's voice
            wav = self.tts_model.tts(
                text=normalized_text,
                speaker_wav=voice_sample,
                language="en"
            )
        else:
            print("   ⚠️ No voice profile yet. Using default voice.")
            wav = self.tts_model.tts(text=normalized_text, language="en")
        
        audio = np.array(wav, dtype=np.float32)
        self.last_audio_output = audio
        
        if save:
            self._save_output(audio, normalized_text)
        
        print("✅ Clear version ready!")
        return audio
    
    def _get_voice_sample(self) -> Optional[str]:
        """Get user's voice sample for cloning."""
        # Explicit path
        if self.voice_sample_path and Path(self.voice_sample_path).exists():
            return str(self.voice_sample_path)
        
        # Check raw samples (user recordings)
        if RAW_SAMPLES_DIR.exists():
            samples = sorted(
                RAW_SAMPLES_DIR.glob("*.wav"),
                key=lambda x: x.stat().st_mtime,
                reverse=True
            )
            for s in samples:
                if s.stat().st_size > 5000:  # At least 5KB
                    return str(s)
        
        # Check clean samples
        if VOICE_SAMPLES_DIR.exists():
            samples = list(VOICE_SAMPLES_DIR.glob("*.wav"))
            for s in samples:
                if s.stat().st_size > 5000:
                    return str(s)
        
        return None
    
    def _save_output(self, audio: np.ndarray, text: str):
        """Save output audio."""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filepath = OUTPUT_DIR / f"bridge_{timestamp}.wav"
        
        audio_int = (audio * 32767).astype(np.int16)
        with wave.open(str(filepath), 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(22050)
            wf.writeframes(audio_int.tobytes())
        
        print(f"   💾 Saved: {filepath.name}")
    
    # -------------------------------------------------------------------------
    # PLAYBACK
    # -------------------------------------------------------------------------
    
    def play(self, audio: np.ndarray):
        """Play audio through speakers."""
        if audio is None or len(audio) == 0:
            return
        
        print("▶️  Playing clear version...")
        sd.play(audio, 22050)
        sd.wait()
    
    # -------------------------------------------------------------------------
    # MAIN PIPELINE
    # -------------------------------------------------------------------------
    
    def process(self, mode: str = "auto", duration: float = 5.0) -> Tuple[str, np.ndarray]:
        """
        Run the full DENUEL VOICE BRIDGE pipeline.
        
        Args:
            mode: "auto" (stop on silence) or "fixed" (fixed duration)
            duration: Duration for fixed mode
            
        Returns:
            (normalized_text, audio_output)
        """
        print("\n" + "="*50)
        print("🌉 DENUEL VOICE BRIDGE")
        print("="*50 + "\n")
        
        # 1. LISTEN (private)
        if mode == "auto":
            raw_audio = self.record_until_silence()
        else:
            raw_audio = self.record_fixed_duration(duration)
        
        if len(raw_audio) == 0:
            print("❌ No audio captured")
            return None, None
        
        # 2. CLEAN (remove noise, isolate user)
        clean_audio = self.clean_audio(raw_audio)
        
        # 3. UNDERSTAND (what did user mean?)
        text = self.understand(clean_audio)
        
        if not text:
            print("❌ No speech detected")
            return None, None
        
        # 4. GENERATE CLEAR OUTPUT (for public)
        audio_out = self.generate_clear_speech(text, save=True)
        
        # 5. PLAY
        if audio_out is not None:
            self.play(audio_out)
        
        print("\n✅ Message delivered clearly!")
        return text, audio_out
    
    def process_text(self, text: str) -> np.ndarray:
        """
        Process text directly (skip recording).
        
        Useful for testing or when text is already known.
        """
        print(f"\n📝 Processing: \"{text}\"")
        audio_out = self.generate_clear_speech(text, save=True)
        if audio_out is not None:
            self.play(audio_out)
        return audio_out

    # -------------------------------------------------------------------------
    # FEATURE 2: PRESENTATION MODE
    # -------------------------------------------------------------------------
    
    def presentation_mode(self):
        """
        PRESENTATION MODE
        
        For prepared speaking: paste notes or speak quietly,
        system outputs clear, professional speech.
        
        Use cases:
        - Presentations
        - Reading prepared text
        - Recording voice messages
        
        The user controls pacing. No live pressure.
        """
        print("\n" + "="*60)
        print("📊 PRESENTATION MODE")
        print("   Speak clearly. Take your time.")
        print("="*60)
        print("\nOptions:")
        print("   1. Type or paste your notes")
        print("   2. Speak your notes (auto-stop on silence)")
        print("   q. Exit presentation mode")
        print()
        
        while True:
            try:
                choice = input("Choose [1/2/q]: ").strip().lower()
            except (EOFError, KeyboardInterrupt):
                break
            
            if choice == 'q':
                print("📊 Exiting presentation mode")
                break
            
            elif choice == '1':
                # Text input mode
                print("\nPaste or type your notes (empty line to finish):")
                lines = []
                while True:
                    try:
                        line = input()
                        if line == "":
                            break
                        lines.append(line)
                    except EOFError:
                        break
                
                text = " ".join(lines).strip()
                if text:
                    print(f"\n📝 Notes received ({len(text.split())} words)")
                    
                    # Process in sentences for natural pacing
                    self._present_text(text)
                else:
                    print("⚠️ No text entered")
            
            elif choice == '2':
                # Voice input mode (quiet speech)
                print("\n🎤 Speak your notes now (will stop when you pause)...")
                raw_audio = self.record_until_silence(max_duration=60.0)
                
                if len(raw_audio) == 0:
                    print("⚠️ No audio captured")
                    continue
                
                clean_audio = self.clean_audio(raw_audio)
                text = self.understand(clean_audio)
                
                if text:
                    self._present_text(text)
                else:
                    print("⚠️ No speech detected")
            
            print()  # Spacing before next prompt
    
    def _present_text(self, text: str):
        """
        Present text with calm, professional pacing.
        
        Splits into sentences and processes each with slight pauses.
        """
        import re
        
        # Split into sentences
        sentences = re.split(r'(?<=[.!?])\s+', text)
        sentences = [s.strip() for s in sentences if s.strip()]
        
        if not sentences:
            return
        
        print(f"\n▶️ Presenting {len(sentences)} sentence(s)...\n")
        
        for i, sentence in enumerate(sentences, 1):
            # Generate and play each sentence
            audio = self.generate_clear_speech(sentence, save=False)
            
            if audio is not None:
                print(f"   [{i}/{len(sentences)}] \"{sentence[:50]}{'...' if len(sentence) > 50 else ''}\"")
                sd.play(audio, 22050)
                sd.wait()
                
                # Brief pause between sentences for natural pacing
                if i < len(sentences):
                    time.sleep(0.3)
        
        # Save the full presentation
        full_audio = self.generate_clear_speech(text, save=True)
        self.last_audio_output = full_audio
        
        print("\n✅ Presentation complete!")

    # -------------------------------------------------------------------------
    # FEATURE 3: LIVE CONFIDENCE MODE
    # -------------------------------------------------------------------------
    
    def live_confidence_mode(self):
        """
        LIVE CONFIDENCE MODE
        
        Real-time assistive speaking for meetings, classes, public situations.
        
        Behavior:
        - Continuous listening
        - Short processing delay (0.5-1s)
        - Outputs clear speech in user's voice
        - Immediate stop on any key press
        
        Safety:
        - User can exit instantly
        - No interruption of user's speech
        - No error messages shown
        """
        print("\n" + "="*60)
        print("🔴 LIVE CONFIDENCE MODE")
        print("   Real-time voice bridge. You speak, we clarify.")
        print("="*60)
        print("\n⚠️  Press ENTER at any time to STOP immediately")
        print("   The audience should only hear the output speaker.\n")
        
        # Pre-load models for minimal latency
        print("🔧 Preparing...")
        self.load_whisper()
        self.load_tts()
        print("✅ Ready!\n")
        
        input("Press ENTER to start live mode...")
        print("\n🔴 LIVE - Speak now (ENTER to stop)\n")
        
        self._live_mode_active = True
        self._stop_requested = False
        
        # Start background listener for stop command
        import threading
        
        def wait_for_stop():
            try:
                input()  # Wait for ENTER
                self._stop_requested = True
            except:
                self._stop_requested = True
        
        stop_thread = threading.Thread(target=wait_for_stop, daemon=True)
        stop_thread.start()
        
        # Live processing loop
        try:
            self._live_processing_loop()
        except KeyboardInterrupt:
            pass
        finally:
            self._live_mode_active = False
            print("\n\n🔴 LIVE MODE ENDED")
            print("   You did great! 💪\n")
    
    def _live_processing_loop(self):
        """
        Core live processing loop.
        
        Continuously captures audio in chunks, processes when speech ends,
        and outputs clear audio with minimal delay.
        """
        chunk_duration = 0.1  # 100ms chunks
        chunk_samples = int(chunk_duration * SAMPLE_RATE)
        
        audio_buffer = []
        speech_active = False
        silence_count = 0
        max_silence_chunks = 8  # ~800ms of silence triggers processing
        
        self.vad.reset()
        
        # Audio input stream
        stream = sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=CHANNELS,
            dtype='float32',
            blocksize=chunk_samples
        )
        stream.start()
        
        try:
            while not self._stop_requested:
                # Read audio chunk
                chunk, overflowed = stream.read(chunk_samples)
                chunk = chunk[:, 0] if len(chunk.shape) > 1 else chunk
                
                # Check for speech
                is_speech = self.vad.process_chunk(chunk)
                
                if is_speech:
                    speech_active = True
                    silence_count = 0
                    audio_buffer.append(chunk.copy())
                elif speech_active:
                    silence_count += 1
                    audio_buffer.append(chunk.copy())  # Include trailing silence
                    
                    # Speech ended - process the utterance
                    if silence_count >= max_silence_chunks:
                        if len(audio_buffer) > 5:  # At least 500ms of audio
                            self._process_live_utterance(audio_buffer)
                        
                        # Reset for next utterance
                        audio_buffer = []
                        speech_active = False
                        silence_count = 0
                        self.vad.reset()
        
        finally:
            stream.stop()
            stream.close()
    
    def _process_live_utterance(self, audio_chunks: List[np.ndarray]):
        """
        Process a single utterance in live mode.
        
        Fast path: minimal logging, quick turnaround.
        """
        if self._stop_requested:
            return
        
        # Combine audio chunks
        audio = np.concatenate(audio_chunks)
        
        # Clean audio (noise + speaker isolation)
        audio = self.clean_audio(audio)
        
        if self._stop_requested:
            return
        
        # Quick transcription
        try:
            result = self.whisper_model.transcribe(
                audio,
                language="en",
                fp16=(self.device == "cuda"),
                temperature=0.0,
                no_speech_threshold=0.6,
            )
            text = result["text"].strip()
        except:
            return  # Silent fail - no error messages in live mode
        
        if not text or self._stop_requested:
            return
        
        # Apply corrections (phrase memory + normalization)
        corrected = self.phrase_memory.apply_corrections(text)
        normalized = self.normalizer.normalize(corrected)
        
        if self._stop_requested:
            return
        
        # Generate clear speech
        voice_sample = self._get_voice_sample()
        
        try:
            if voice_sample:
                wav = self.tts_model.tts(
                    text=normalized,
                    speaker_wav=voice_sample,
                    language="en"
                )
            else:
                wav = self.tts_model.tts(text=normalized, language="en")
            
            audio_out = np.array(wav, dtype=np.float32)
            
            if not self._stop_requested:
                # Play immediately
                sd.play(audio_out, 22050)
                sd.wait()
        except:
            pass  # Silent fail
    
    def stop_live_mode(self):
        """Emergency stop for live mode."""
        self._stop_requested = True
        self._live_mode_active = False


# =============================================================================
# INTERACTIVE MODE
# =============================================================================

def print_help():
    """Print help menu."""
    print("\n" + "-"*50)
    print("📖 Commands:")
    print("-"*50)
    print("   ENTER    - Speak and process")
    print("   t        - Type text to process")
    print("   f        - Fixed duration recording (5s)")
    print("   r        - Replay last output")
    print("   l        - Learn a word correction")
    print("   p        - Phrase memory settings")
    print("   P        - PRESENTATION MODE")
    print("   L        - LIVE CONFIDENCE MODE")
    print("   v        - List voice samples")
    print("   h        - Show this help")
    print("   q        - Quit")
    print("-"*50 + "\n")


def interactive_mode():
    """Run DENUEL VOICE BRIDGE in interactive mode."""
    print("\n" + "="*60)
    print("🌉 DENUEL VOICE BRIDGE")
    print("   Your voice. Clear and confident.")
    print("="*60)
    
    bridge = DenuelVoiceBridge()
    print_help()
    
    while True:
        try:
            cmd = input("\n>>> ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            break
        
        if cmd == 'q':
            print("👋 Goodbye!")
            break
        
        elif cmd == 'h':
            print_help()
        
        elif cmd == '' or cmd == 'a':
            # Auto mode - speak until silence
            try:
                bridge.process(mode="auto")
            except Exception as e:
                print(f"❌ Error: {e}")
        
        elif cmd == 'f':
            # Fixed duration
            try:
                bridge.process(mode="fixed", duration=5.0)
            except Exception as e:
                print(f"❌ Error: {e}")
        
        elif cmd == 't':
            text = input("Type what you want to say: ").strip()
            if text:
                bridge.process_text(text)
        
        elif cmd == 'r':
            if bridge.last_audio_output is not None:
                bridge.play(bridge.last_audio_output)
            else:
                print("⚠️ No previous output to replay")
        
        elif cmd == 'l':
            print("\n📚 Teach a word correction:")
            heard = input("   What did the system hear? ").strip()
            intended = input("   What did you mean? ").strip()
            if heard and intended:
                bridge.normalizer.learn_correction(heard, intended)
                print(f"   ✅ Learned: \"{heard}\" → \"{intended}\"")
        
        elif cmd == 'p':
            # Phrase memory management
            print("\n📚 Phrase Memory")
            print(bridge.phrase_memory.get_summary())
            print("\nOptions:")
            print("   1. Set your name")
            print("   2. Add name correction (e.g., Monroe → Emmanuel)")
            print("   3. Add phrase correction")
            print("   4. View all corrections")
            print("   b. Back")
            
            sub = input("\nChoice: ").strip()
            
            if sub == '1':
                name = input("Your name: ").strip()
                if name:
                    bridge.phrase_memory.set_user_name(name)
                    print(f"✅ Name set to: {name}")
            
            elif sub == '2':
                heard = input("What might be heard wrong? ").strip()
                correct = input("Correct name: ").strip()
                if heard and correct:
                    bridge.phrase_memory.add_name(heard, correct)
                    print(f"✅ Name learned: \"{heard}\" → \"{correct}\"")
            
            elif sub == '3':
                heard = input("Phrase as heard: ").strip()
                intended = input("Intended phrase: ").strip()
                if heard and intended:
                    bridge.phrase_memory.add_phrase_correction(heard, intended)
                    print(f"✅ Phrase learned: \"{heard}\" → \"{intended}\"")
            
            elif sub == '4':
                print("\n--- Names ---")
                for h, c in bridge.phrase_memory.known_names.items():
                    print(f"   {h} → {c}")
                print("\n--- Phrases ---")
                for h, c in bridge.phrase_memory.phrase_corrections.items():
                    print(f"   {h} → {c}")
        
        elif cmd == 'P' or cmd == 'presentation':
            # Presentation Mode (Feature 2)
            try:
                bridge.presentation_mode()
            except Exception as e:
                print(f"❌ Error: {e}")
        
        elif cmd == 'L' or cmd == 'live':
            # Live Confidence Mode (Feature 3)
            try:
                bridge.live_confidence_mode()
            except Exception as e:
                print(f"❌ Error: {e}")
        
        elif cmd == 'v':
            sample = bridge._get_voice_sample()
            if sample:
                print(f"🎤 Current voice sample: {Path(sample).name}")
            else:
                print("⚠️ No voice sample found. Record one first!")


def main():
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="DENUEL VOICE BRIDGE - Assistive Speech System"
    )
    parser.add_argument("--text", "-t", type=str,
                       help="Process text directly")
    parser.add_argument("--voice", "-v", type=str,
                       help="Path to voice sample")
    parser.add_argument("--interactive", "-i", action="store_true",
                       help="Run in interactive mode")
    parser.add_argument("--presentation", "-P", action="store_true",
                       help="Start in Presentation Mode")
    parser.add_argument("--live", "-L", action="store_true",
                       help="Start in Live Confidence Mode")
    
    args = parser.parse_args()
    
    if args.presentation:
        bridge = DenuelVoiceBridge(voice_sample_path=args.voice)
        bridge.presentation_mode()
    elif args.live:
        bridge = DenuelVoiceBridge(voice_sample_path=args.voice)
        bridge.live_confidence_mode()
    elif args.interactive or (not args.text):
        interactive_mode()
    else:
        bridge = DenuelVoiceBridge(voice_sample_path=args.voice)
        bridge.process_text(args.text)


if __name__ == "__main__":
    main()
