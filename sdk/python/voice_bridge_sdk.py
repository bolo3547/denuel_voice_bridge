"""
Denuel Voice Bridge - Python SDK
================================
Official Python client for the Voice Bridge API.

Installation:
    pip install voice-bridge-sdk  # (or copy this file)

Usage:
    from voice_bridge_sdk import VoiceBridgeClient
    
    client = VoiceBridgeClient(api_key="your-api-key")
    
    # Transcribe audio
    result = client.transcribe("audio.wav")
    print(result.text)
    
    # Synthesize speech
    audio = client.synthesize("Hello, world!")
    audio.save("output.wav")
"""

import os
import json
import base64
import time
from pathlib import Path
from typing import Optional, Dict, List, Union, BinaryIO
from dataclasses import dataclass
import urllib.request
import urllib.parse

# Try to import httpx for async support
try:
    import httpx
    HTTPX_AVAILABLE = True
except ImportError:
    HTTPX_AVAILABLE = False

# Try to import websockets for streaming
try:
    import websockets
    WEBSOCKETS_AVAILABLE = True
except ImportError:
    WEBSOCKETS_AVAILABLE = False


# =============================================================================
# CONFIGURATION
# =============================================================================

DEFAULT_BASE_URL = "http://localhost:8000"
DEFAULT_TIMEOUT = 60
CHUNK_SIZE = 8192


# =============================================================================
# RESPONSE MODELS
# =============================================================================

@dataclass
class TranscriptionResult:
    """Result of a transcription request."""
    text: str
    language: str
    confidence: float = 1.0
    words: List[Dict] = None
    duration_seconds: float = 0.0
    
    @classmethod
    def from_dict(cls, data: Dict) -> "TranscriptionResult":
        return cls(
            text=data.get("text", ""),
            language=data.get("language", "en"),
            confidence=data.get("confidence", 1.0),
            words=data.get("words"),
            duration_seconds=data.get("duration_seconds", 0.0)
        )


@dataclass
class SynthesisResult:
    """Result of a synthesis request."""
    audio_data: bytes
    sample_rate: int = 22050
    format: str = "wav"
    duration_seconds: float = 0.0
    
    def save(self, path: Union[str, Path]):
        """Save audio to file."""
        with open(path, 'wb') as f:
            f.write(self.audio_data)
    
    def to_base64(self) -> str:
        """Get audio as base64 string."""
        return base64.b64encode(self.audio_data).decode()
    
    @classmethod
    def from_response(cls, data: bytes, metadata: Dict = None) -> "SynthesisResult":
        metadata = metadata or {}
        return cls(
            audio_data=data,
            sample_rate=metadata.get("sample_rate", 22050),
            format=metadata.get("format", "wav"),
            duration_seconds=metadata.get("duration_seconds", 0.0)
        )


@dataclass
class VoiceProfile:
    """Voice profile information."""
    id: str
    name: str
    language: str
    description: str = ""
    created_at: str = ""
    sample_count: int = 0
    
    @classmethod
    def from_dict(cls, data: Dict) -> "VoiceProfile":
        return cls(
            id=data.get("id", ""),
            name=data.get("name", ""),
            language=data.get("language", "en"),
            description=data.get("description", ""),
            created_at=data.get("created_at", ""),
            sample_count=data.get("sample_count", 0)
        )


@dataclass
class Job:
    """Background job information."""
    id: str
    type: str
    status: str
    progress: int = 0
    result: Dict = None
    error: str = None
    created_at: str = ""
    completed_at: str = ""
    
    @classmethod
    def from_dict(cls, data: Dict) -> "Job":
        return cls(
            id=data.get("id", ""),
            type=data.get("type", ""),
            status=data.get("status", "pending"),
            progress=data.get("progress", 0),
            result=data.get("result"),
            error=data.get("error"),
            created_at=data.get("created_at", ""),
            completed_at=data.get("completed_at", "")
        )


# =============================================================================
# EXCEPTIONS
# =============================================================================

class VoiceBridgeError(Exception):
    """Base exception for Voice Bridge SDK."""
    pass


class AuthenticationError(VoiceBridgeError):
    """Authentication failed."""
    pass


class RateLimitError(VoiceBridgeError):
    """Rate limit exceeded."""
    def __init__(self, message: str, retry_after: int = None):
        super().__init__(message)
        self.retry_after = retry_after


class APIError(VoiceBridgeError):
    """API returned an error."""
    def __init__(self, message: str, status_code: int = None, details: Dict = None):
        super().__init__(message)
        self.status_code = status_code
        self.details = details


# =============================================================================
# SYNC CLIENT
# =============================================================================

class VoiceBridgeClient:
    """
    Synchronous client for the Voice Bridge API.
    
    Example:
        client = VoiceBridgeClient(api_key="vb_xxx")
        result = client.transcribe("audio.wav")
        print(result.text)
    """
    
    def __init__(
        self,
        api_key: str = None,
        base_url: str = None,
        timeout: int = DEFAULT_TIMEOUT
    ):
        self.api_key = api_key or os.environ.get("VOICE_BRIDGE_API_KEY")
        self.base_url = (base_url or os.environ.get("VOICE_BRIDGE_URL", DEFAULT_BASE_URL)).rstrip("/")
        self.timeout = timeout
        
        if not self.api_key:
            raise AuthenticationError("API key required. Set api_key parameter or VOICE_BRIDGE_API_KEY env var.")
    
    def _request(
        self,
        method: str,
        endpoint: str,
        data: Dict = None,
        files: Dict = None,
        params: Dict = None
    ) -> Dict:
        """Make HTTP request to API."""
        url = f"{self.base_url}{endpoint}"
        
        if params:
            url += "?" + urllib.parse.urlencode(params)
        
        headers = {
            "X-API-Key": self.api_key,
            "User-Agent": "VoiceBridge-Python-SDK/1.0"
        }
        
        body = None
        if data:
            headers["Content-Type"] = "application/json"
            body = json.dumps(data).encode()
        
        request = urllib.request.Request(url, data=body, headers=headers, method=method)
        
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                content = response.read()
                if response.headers.get("Content-Type", "").startswith("application/json"):
                    return json.loads(content)
                return {"data": content}
        
        except urllib.error.HTTPError as e:
            if e.code == 401:
                raise AuthenticationError("Invalid API key")
            elif e.code == 429:
                retry_after = e.headers.get("Retry-After", 60)
                raise RateLimitError(f"Rate limit exceeded. Retry after {retry_after}s", int(retry_after))
            else:
                try:
                    error_body = json.loads(e.read())
                    raise APIError(error_body.get("detail", str(e)), e.code, error_body)
                except json.JSONDecodeError:
                    raise APIError(str(e), e.code)
    
    def _upload_audio(self, endpoint: str, audio: Union[str, Path, bytes, BinaryIO], **kwargs) -> Dict:
        """Upload audio file to API."""
        # Read audio data
        if isinstance(audio, (str, Path)):
            with open(audio, 'rb') as f:
                audio_data = f.read()
        elif isinstance(audio, bytes):
            audio_data = audio
        else:
            audio_data = audio.read()
        
        # Encode to base64
        audio_base64 = base64.b64encode(audio_data).decode()
        
        data = {"audio_base64": audio_base64, **kwargs}
        return self._request("POST", endpoint, data=data)
    
    # =========================================================================
    # TRANSCRIPTION
    # =========================================================================
    
    def transcribe(
        self,
        audio: Union[str, Path, bytes, BinaryIO],
        language: str = "en"
    ) -> TranscriptionResult:
        """
        Transcribe audio to text.
        
        Args:
            audio: Audio file path, bytes, or file-like object
            language: Language code (e.g., "en", "es", "fr")
        
        Returns:
            TranscriptionResult with text and metadata
        """
        result = self._upload_audio("/transcribe", audio, language=language)
        return TranscriptionResult.from_dict(result)
    
    # =========================================================================
    # SYNTHESIS
    # =========================================================================
    
    def synthesize(
        self,
        text: str,
        language: str = "en",
        voice_profile_id: str = None,
        voice_sample: Union[str, Path, bytes] = None,
        speed: float = 1.0
    ) -> SynthesisResult:
        """
        Synthesize text to speech.
        
        Args:
            text: Text to synthesize
            language: Language code
            voice_profile_id: Optional voice profile ID for cloning
            voice_sample: Optional audio sample for one-shot cloning
            speed: Speech speed multiplier (0.5 - 2.0)
        
        Returns:
            SynthesisResult with audio data
        """
        data = {
            "text": text,
            "language": language,
            "speed": speed
        }
        
        if voice_profile_id:
            data["voice_profile_id"] = voice_profile_id
        
        if voice_sample:
            if isinstance(voice_sample, (str, Path)):
                with open(voice_sample, 'rb') as f:
                    sample_data = f.read()
            else:
                sample_data = voice_sample
            data["voice_sample_base64"] = base64.b64encode(sample_data).decode()
        
        result = self._request("POST", "/synthesize", data=data)
        
        audio_data = base64.b64decode(result.get("audio_base64", ""))
        return SynthesisResult.from_response(audio_data, result)
    
    # =========================================================================
    # VOICE CLONING
    # =========================================================================
    
    def clone(
        self,
        audio: Union[str, Path, bytes, BinaryIO],
        language: str = "en",
        target_language: str = None,
        voice_profile_id: str = None,
        enhance_audio: bool = True
    ) -> Dict:
        """
        Full voice cloning pipeline: transcribe, process, and synthesize.
        
        Args:
            audio: Input audio
            language: Source language
            target_language: Target language for translation (optional)
            voice_profile_id: Voice profile for synthesis
            enhance_audio: Whether to enhance input audio
        
        Returns:
            Dict with transcription and synthesized audio
        """
        result = self._upload_audio(
            "/clone",
            audio,
            language=language,
            target_language=target_language,
            voice_profile_id=voice_profile_id,
            enhance_audio=enhance_audio
        )
        return result
    
    # =========================================================================
    # AUDIO ENHANCEMENT
    # =========================================================================
    
    def enhance(
        self,
        audio: Union[str, Path, bytes, BinaryIO],
        denoise: bool = True,
        normalize: bool = True,
        trim_silence: bool = True
    ) -> SynthesisResult:
        """
        Enhance audio quality.
        
        Args:
            audio: Input audio
            denoise: Remove background noise
            normalize: Normalize volume
            trim_silence: Trim silence from start/end
        
        Returns:
            SynthesisResult with enhanced audio
        """
        result = self._upload_audio(
            "/enhance",
            audio,
            denoise=denoise,
            normalize=normalize,
            trim_silence=trim_silence
        )
        
        audio_data = base64.b64decode(result.get("audio_base64", ""))
        return SynthesisResult.from_response(audio_data, result)
    
    # =========================================================================
    # VOICE PROFILES
    # =========================================================================
    
    def list_profiles(self) -> List[VoiceProfile]:
        """List all voice profiles."""
        result = self._request("GET", "/profiles")
        return [VoiceProfile.from_dict(p) for p in result.get("profiles", [])]
    
    def get_profile(self, profile_id: str) -> VoiceProfile:
        """Get a specific voice profile."""
        result = self._request("GET", f"/profiles/{profile_id}")
        return VoiceProfile.from_dict(result)
    
    def create_profile(
        self,
        name: str,
        language: str = "en",
        description: str = ""
    ) -> VoiceProfile:
        """Create a new voice profile."""
        result = self._request("POST", "/profiles", data={
            "name": name,
            "language": language,
            "description": description
        })
        return VoiceProfile.from_dict(result)
    
    def add_profile_sample(
        self,
        profile_id: str,
        audio: Union[str, Path, bytes, BinaryIO]
    ) -> Dict:
        """Add a voice sample to a profile."""
        return self._upload_audio(f"/profiles/sample", audio, profile_id=profile_id)
    
    def delete_profile(self, profile_id: str) -> Dict:
        """Delete a voice profile."""
        return self._request("DELETE", f"/profiles/{profile_id}")
    
    # =========================================================================
    # BACKGROUND JOBS
    # =========================================================================
    
    def create_job(
        self,
        job_type: str,
        input_data: Dict,
        webhook_url: str = None
    ) -> Job:
        """Create a background job."""
        result = self._request("POST", "/jobs", data={
            "job_type": job_type,
            "input_data": input_data,
            "webhook_url": webhook_url
        })
        return Job.from_dict(result)
    
    def get_job(self, job_id: str) -> Job:
        """Get job status."""
        result = self._request("GET", f"/jobs/{job_id}")
        return Job.from_dict(result)
    
    def wait_for_job(self, job_id: str, poll_interval: float = 1.0, timeout: float = 300) -> Job:
        """Wait for a job to complete."""
        start_time = time.time()
        
        while True:
            job = self.get_job(job_id)
            
            if job.status in ["completed", "failed", "cancelled"]:
                return job
            
            if time.time() - start_time > timeout:
                raise TimeoutError(f"Job {job_id} did not complete within {timeout}s")
            
            time.sleep(poll_interval)
    
    def cancel_job(self, job_id: str) -> Dict:
        """Cancel a pending job."""
        return self._request("POST", f"/jobs/{job_id}/cancel")
    
    # =========================================================================
    # USAGE & BILLING
    # =========================================================================
    
    def get_usage(self) -> Dict:
        """Get current usage and limits."""
        return self._request("GET", "/billing/usage")
    
    def get_plans(self) -> List[Dict]:
        """List available plans."""
        result = self._request("GET", "/billing/plans")
        return result
    
    # =========================================================================
    # HEALTH & STATUS
    # =========================================================================
    
    def health(self) -> Dict:
        """Check API health."""
        return self._request("GET", "/health")
    
    def status(self) -> Dict:
        """Get API status."""
        return self._request("GET", "/")


# =============================================================================
# ASYNC CLIENT
# =============================================================================

if HTTPX_AVAILABLE:
    class AsyncVoiceBridgeClient:
        """
        Asynchronous client for the Voice Bridge API.
        
        Example:
            async with AsyncVoiceBridgeClient(api_key="vb_xxx") as client:
                result = await client.transcribe("audio.wav")
                print(result.text)
        """
        
        def __init__(
            self,
            api_key: str = None,
            base_url: str = None,
            timeout: int = DEFAULT_TIMEOUT
        ):
            self.api_key = api_key or os.environ.get("VOICE_BRIDGE_API_KEY")
            self.base_url = (base_url or os.environ.get("VOICE_BRIDGE_URL", DEFAULT_BASE_URL)).rstrip("/")
            self.timeout = timeout
            self._client: Optional[httpx.AsyncClient] = None
            
            if not self.api_key:
                raise AuthenticationError("API key required")
        
        async def __aenter__(self):
            self._client = httpx.AsyncClient(
                base_url=self.base_url,
                timeout=self.timeout,
                headers={
                    "X-API-Key": self.api_key,
                    "User-Agent": "VoiceBridge-Python-SDK/1.0"
                }
            )
            return self
        
        async def __aexit__(self, *args):
            if self._client:
                await self._client.aclose()
        
        async def _request(self, method: str, endpoint: str, **kwargs) -> Dict:
            """Make async HTTP request."""
            response = await self._client.request(method, endpoint, **kwargs)
            
            if response.status_code == 401:
                raise AuthenticationError("Invalid API key")
            elif response.status_code == 429:
                retry_after = response.headers.get("Retry-After", 60)
                raise RateLimitError(f"Rate limit exceeded", int(retry_after))
            elif response.status_code >= 400:
                try:
                    error_body = response.json()
                    raise APIError(error_body.get("detail", "Unknown error"), response.status_code, error_body)
                except json.JSONDecodeError:
                    raise APIError(response.text, response.status_code)
            
            if response.headers.get("Content-Type", "").startswith("application/json"):
                return response.json()
            return {"data": response.content}
        
        async def transcribe(
            self,
            audio: Union[str, Path, bytes],
            language: str = "en"
        ) -> TranscriptionResult:
            """Transcribe audio to text."""
            if isinstance(audio, (str, Path)):
                with open(audio, 'rb') as f:
                    audio_data = f.read()
            else:
                audio_data = audio
            
            audio_base64 = base64.b64encode(audio_data).decode()
            
            result = await self._request("POST", "/transcribe", json={
                "audio_base64": audio_base64,
                "language": language
            })
            
            return TranscriptionResult.from_dict(result)
        
        async def synthesize(
            self,
            text: str,
            language: str = "en",
            voice_profile_id: str = None,
            speed: float = 1.0
        ) -> SynthesisResult:
            """Synthesize text to speech."""
            data = {
                "text": text,
                "language": language,
                "speed": speed
            }
            
            if voice_profile_id:
                data["voice_profile_id"] = voice_profile_id
            
            result = await self._request("POST", "/synthesize", json=data)
            
            audio_data = base64.b64decode(result.get("audio_base64", ""))
            return SynthesisResult.from_response(audio_data, result)
        
        async def health(self) -> Dict:
            """Check API health."""
            return await self._request("GET", "/health")


# =============================================================================
# CONVENIENCE FUNCTIONS
# =============================================================================

def transcribe(audio: Union[str, Path, bytes], api_key: str = None, **kwargs) -> TranscriptionResult:
    """Quick transcription without creating a client."""
    client = VoiceBridgeClient(api_key=api_key)
    return client.transcribe(audio, **kwargs)


def synthesize(text: str, api_key: str = None, **kwargs) -> SynthesisResult:
    """Quick synthesis without creating a client."""
    client = VoiceBridgeClient(api_key=api_key)
    return client.synthesize(text, **kwargs)


# =============================================================================
# CLI
# =============================================================================

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Voice Bridge CLI")
    parser.add_argument("command", choices=["transcribe", "synthesize", "health"])
    parser.add_argument("--input", "-i", help="Input file or text")
    parser.add_argument("--output", "-o", help="Output file")
    parser.add_argument("--api-key", help="API key")
    parser.add_argument("--language", "-l", default="en", help="Language code")
    
    args = parser.parse_args()
    
    client = VoiceBridgeClient(api_key=args.api_key)
    
    if args.command == "transcribe":
        result = client.transcribe(args.input, language=args.language)
        print(result.text)
    
    elif args.command == "synthesize":
        result = client.synthesize(args.input, language=args.language)
        output_path = args.output or "output.wav"
        result.save(output_path)
        print(f"Saved to {output_path}")
    
    elif args.command == "health":
        result = client.health()
        print(json.dumps(result, indent=2))
