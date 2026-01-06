"""
Voice Profile Manager
=====================
Manage multiple voice profiles with metadata and quality ratings.

Features:
- Save/load voice profiles
- Profile metadata management
- Quality ratings and validation
- Profile comparison
- Export/import (encrypted optional)
"""

import json
import hashlib
import wave
import numpy as np
from pathlib import Path
from datetime import datetime
from dataclasses import dataclass, asdict
from typing import List, Optional, Dict
import shutil

# Project paths
PROJECT_ROOT = Path(__file__).parent.parent.parent
PROFILES_DIR = PROJECT_ROOT / "data" / "voice_profiles"
VOICE_SAMPLES_DIR = PROJECT_ROOT / "data" / "voice_profile_clean"
RAW_SAMPLES_DIR = PROJECT_ROOT / "data" / "voice_profile_raw"


@dataclass
class VoiceProfile:
    """Voice profile data structure."""
    id: str
    name: str
    description: str
    created_at: str
    updated_at: str
    language: str
    sample_paths: List[str]
    sample_count: int
    total_duration_seconds: float
    quality_rating: float  # 1-5 scale
    tags: List[str]
    metadata: Dict
    
    def to_dict(self) -> dict:
        return asdict(self)
    
    @classmethod
    def from_dict(cls, data: dict) -> 'VoiceProfile':
        return cls(**data)


class VoiceProfileManager:
    """Manage voice profiles for voice cloning."""
    
    def __init__(self):
        self.profiles_dir = PROFILES_DIR
        self.profiles_dir.mkdir(parents=True, exist_ok=True)
        self.profiles_index_path = self.profiles_dir / "profiles_index.json"
        self._profiles: Dict[str, VoiceProfile] = {}
        self._load_index()
    
    def _load_index(self):
        """Load profiles index from disk."""
        if self.profiles_index_path.exists():
            try:
                with open(self.profiles_index_path, 'r') as f:
                    data = json.load(f)
                    for profile_data in data.get("profiles", []):
                        profile = VoiceProfile.from_dict(profile_data)
                        self._profiles[profile.id] = profile
            except Exception as e:
                print(f"⚠️  Error loading profiles index: {e}")
    
    def _save_index(self):
        """Save profiles index to disk."""
        data = {
            "version": "1.0",
            "updated_at": datetime.now().isoformat(),
            "profiles": [p.to_dict() for p in self._profiles.values()]
        }
        with open(self.profiles_index_path, 'w') as f:
            json.dump(data, f, indent=2)
    
    def _generate_id(self, name: str) -> str:
        """Generate unique profile ID."""
        timestamp = datetime.now().isoformat()
        hash_input = f"{name}_{timestamp}"
        return hashlib.md5(hash_input.encode()).hexdigest()[:12]
    
    def create_profile(self, name: str, description: str = "", 
                       language: str = "en", tags: List[str] = None) -> VoiceProfile:
        """
        Create a new voice profile.
        
        Args:
            name: Profile name
            description: Profile description
            language: Language code (e.g., 'en', 'es')
            tags: Optional tags for categorization
        
        Returns:
            Created VoiceProfile
        """
        profile_id = self._generate_id(name)
        now = datetime.now().isoformat()
        
        profile = VoiceProfile(
            id=profile_id,
            name=name,
            description=description,
            created_at=now,
            updated_at=now,
            language=language,
            sample_paths=[],
            sample_count=0,
            total_duration_seconds=0.0,
            quality_rating=0.0,
            tags=tags or [],
            metadata={}
        )
        
        # Create profile directory
        profile_dir = self.profiles_dir / profile_id
        profile_dir.mkdir(exist_ok=True)
        (profile_dir / "samples").mkdir(exist_ok=True)
        
        self._profiles[profile_id] = profile
        self._save_index()
        
        print(f"✅ Created profile: {name} (ID: {profile_id})")
        return profile
    
    def add_sample(self, profile_id: str, audio: np.ndarray, 
                   sample_rate: int = 22050, name: str = None) -> str:
        """
        Add a voice sample to a profile.
        
        Args:
            profile_id: Profile ID
            audio: Audio numpy array
            sample_rate: Sample rate
            name: Optional sample name
        
        Returns:
            Path to saved sample
        """
        if profile_id not in self._profiles:
            raise ValueError(f"Profile not found: {profile_id}")
        
        profile = self._profiles[profile_id]
        profile_dir = self.profiles_dir / profile_id / "samples"
        
        # Generate sample filename
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        sample_name = name or f"sample_{timestamp}"
        sample_path = profile_dir / f"{sample_name}.wav"
        
        # Save audio
        self._save_wav(str(sample_path), audio, sample_rate)
        
        # Update profile
        duration = len(audio) / sample_rate
        profile.sample_paths.append(str(sample_path))
        profile.sample_count += 1
        profile.total_duration_seconds += duration
        profile.updated_at = datetime.now().isoformat()
        
        self._save_index()
        
        print(f"✅ Added sample to profile '{profile.name}': {sample_path.name}")
        return str(sample_path)
    
    def add_sample_file(self, profile_id: str, file_path: str, 
                        copy: bool = True) -> str:
        """
        Add an existing audio file to a profile.
        
        Args:
            profile_id: Profile ID
            file_path: Path to audio file
            copy: Whether to copy file to profile directory
        
        Returns:
            Path to sample (copied or original)
        """
        if profile_id not in self._profiles:
            raise ValueError(f"Profile not found: {profile_id}")
        
        source_path = Path(file_path)
        if not source_path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")
        
        profile = self._profiles[profile_id]
        
        if copy:
            # Copy to profile directory
            profile_dir = self.profiles_dir / profile_id / "samples"
            dest_path = profile_dir / source_path.name
            
            # Handle duplicates
            counter = 1
            while dest_path.exists():
                stem = source_path.stem
                suffix = source_path.suffix
                dest_path = profile_dir / f"{stem}_{counter}{suffix}"
                counter += 1
            
            shutil.copy2(source_path, dest_path)
            sample_path = str(dest_path)
        else:
            sample_path = str(source_path)
        
        # Get duration
        duration = self._get_audio_duration(sample_path)
        
        # Update profile
        profile.sample_paths.append(sample_path)
        profile.sample_count += 1
        profile.total_duration_seconds += duration
        profile.updated_at = datetime.now().isoformat()
        
        self._save_index()
        
        print(f"✅ Added sample to profile '{profile.name}'")
        return sample_path
    
    def get_profile(self, profile_id: str) -> Optional[VoiceProfile]:
        """Get a profile by ID."""
        return self._profiles.get(profile_id)
    
    def get_profile_by_name(self, name: str) -> Optional[VoiceProfile]:
        """Get a profile by name."""
        for profile in self._profiles.values():
            if profile.name.lower() == name.lower():
                return profile
        return None
    
    def list_profiles(self) -> List[VoiceProfile]:
        """List all profiles."""
        return list(self._profiles.values())
    
    def delete_profile(self, profile_id: str, delete_files: bool = False):
        """
        Delete a profile.
        
        Args:
            profile_id: Profile ID
            delete_files: Whether to delete sample files too
        """
        if profile_id not in self._profiles:
            raise ValueError(f"Profile not found: {profile_id}")
        
        profile = self._profiles[profile_id]
        
        if delete_files:
            profile_dir = self.profiles_dir / profile_id
            if profile_dir.exists():
                shutil.rmtree(profile_dir)
        
        del self._profiles[profile_id]
        self._save_index()
        
        print(f"✅ Deleted profile: {profile.name}")
    
    def update_quality_rating(self, profile_id: str, rating: float):
        """Update profile quality rating (1-5 scale)."""
        if profile_id not in self._profiles:
            raise ValueError(f"Profile not found: {profile_id}")
        
        rating = max(1.0, min(5.0, rating))
        self._profiles[profile_id].quality_rating = rating
        self._profiles[profile_id].updated_at = datetime.now().isoformat()
        self._save_index()
    
    def get_best_sample(self, profile_id: str) -> Optional[str]:
        """Get the best/longest sample from a profile."""
        if profile_id not in self._profiles:
            return None
        
        profile = self._profiles[profile_id]
        if not profile.sample_paths:
            return None
        
        # Return longest/most recent sample
        valid_samples = [p for p in profile.sample_paths if Path(p).exists()]
        if not valid_samples:
            return None
        
        # Sort by file size (proxy for duration/quality)
        valid_samples.sort(key=lambda p: Path(p).stat().st_size, reverse=True)
        return valid_samples[0]
    
    def export_profile(self, profile_id: str, output_path: str, 
                       include_samples: bool = True) -> str:
        """
        Export a profile to a zip file.
        
        Args:
            profile_id: Profile ID
            output_path: Output zip file path
            include_samples: Whether to include audio samples
        
        Returns:
            Path to exported file
        """
        import zipfile
        
        if profile_id not in self._profiles:
            raise ValueError(f"Profile not found: {profile_id}")
        
        profile = self._profiles[profile_id]
        
        with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zf:
            # Add profile metadata
            profile_json = json.dumps(profile.to_dict(), indent=2)
            zf.writestr("profile.json", profile_json)
            
            # Add samples
            if include_samples:
                for sample_path in profile.sample_paths:
                    if Path(sample_path).exists():
                        arcname = f"samples/{Path(sample_path).name}"
                        zf.write(sample_path, arcname)
        
        print(f"✅ Exported profile to: {output_path}")
        return output_path
    
    def import_profile(self, zip_path: str) -> VoiceProfile:
        """
        Import a profile from a zip file.
        
        Args:
            zip_path: Path to zip file
        
        Returns:
            Imported VoiceProfile
        """
        import zipfile
        
        with zipfile.ZipFile(zip_path, 'r') as zf:
            # Read profile metadata
            profile_data = json.loads(zf.read("profile.json"))
            
            # Generate new ID to avoid conflicts
            old_id = profile_data["id"]
            new_id = self._generate_id(profile_data["name"])
            profile_data["id"] = new_id
            profile_data["sample_paths"] = []
            profile_data["imported_at"] = datetime.now().isoformat()
            
            # Create profile directory
            profile_dir = self.profiles_dir / new_id
            profile_dir.mkdir(exist_ok=True)
            samples_dir = profile_dir / "samples"
            samples_dir.mkdir(exist_ok=True)
            
            # Extract samples
            for name in zf.namelist():
                if name.startswith("samples/") and not name.endswith("/"):
                    # Extract sample
                    sample_name = Path(name).name
                    sample_path = samples_dir / sample_name
                    with zf.open(name) as src, open(sample_path, 'wb') as dst:
                        dst.write(src.read())
                    profile_data["sample_paths"].append(str(sample_path))
            
            profile_data["sample_count"] = len(profile_data["sample_paths"])
            
            profile = VoiceProfile.from_dict(profile_data)
            self._profiles[new_id] = profile
            self._save_index()
            
            print(f"✅ Imported profile: {profile.name} (ID: {new_id})")
            return profile
    
    def _save_wav(self, filepath: str, audio: np.ndarray, sample_rate: int):
        """Save audio to WAV file."""
        audio_int = (audio * 32767).astype(np.int16)
        
        with wave.open(filepath, 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(audio_int.tobytes())
    
    def _get_audio_duration(self, filepath: str) -> float:
        """Get audio duration in seconds."""
        try:
            with wave.open(filepath, 'rb') as wf:
                frames = wf.getnframes()
                rate = wf.getframerate()
                return frames / rate
        except Exception:
            return 0.0
    
    def print_profiles(self):
        """Print all profiles in a nice format."""
        profiles = self.list_profiles()
        
        if not profiles:
            print("\n📁 No voice profiles found.")
            print("   Create one with: manager.create_profile('My Voice')")
            return
        
        print("\n" + "="*60)
        print("📁 Voice Profiles")
        print("="*60)
        
        for i, profile in enumerate(profiles, 1):
            stars = "⭐" * int(profile.quality_rating) if profile.quality_rating else "Not rated"
            print(f"\n{i}. {profile.name}")
            print(f"   ID:        {profile.id}")
            print(f"   Language:  {profile.language}")
            print(f"   Samples:   {profile.sample_count}")
            print(f"   Duration:  {profile.total_duration_seconds:.1f}s")
            print(f"   Rating:    {stars}")
            if profile.tags:
                print(f"   Tags:      {', '.join(profile.tags)}")
        
        print("\n" + "="*60)


# Quick test
if __name__ == "__main__":
    print("📁 Voice Profile Manager")
    print("-" * 40)
    
    manager = VoiceProfileManager()
    manager.print_profiles()
    
    print("\n✅ Voice profile manager ready!")
