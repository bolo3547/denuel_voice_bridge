"""
Voice Bridge API Server
=======================
REST API + WebSocket server for the Voice Bridge pipeline.

Endpoints:
- POST /transcribe - Audio to text (Whisper)
- POST /synthesize - Text to audio (XTTS)
- POST /clone - Full voice cloning pipeline
- POST /enhance - Audio enhancement
- POST /analyze - Voice analysis
- GET /profiles - List voice profiles
- WS /ws/stream - Real-time streaming

Run:
    python ai/api/server.py
    
Or with uvicorn:
    uvicorn ai.api.server:app --host 0.0.0.0 --port 8000 --reload
"""

import os
import sys
import io
import base64
import tempfile
import wave
from pathlib import Path
from typing import Optional, List
from datetime import datetime

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

import numpy as np

try:
    from fastapi import FastAPI, HTTPException, UploadFile, File, Form, WebSocket, WebSocketDisconnect
    from fastapi.middleware.cors import CORSMiddleware
    from fastapi.responses import StreamingResponse, JSONResponse
    from pydantic import BaseModel
except ImportError:
    print("❌ FastAPI not installed. Run: pip install fastapi uvicorn python-multipart")
    sys.exit(1)

# Import pipeline components
try:
    from ai.pipelines.voice_to_text_to_voice import VoiceToTextToVoice
    from ai.utils.audio_enhancer import AudioEnhancer
    from ai.utils.voice_analyzer import VoiceAnalyzer
    from ai.utils.voice_profile_manager import VoiceProfileManager
except ImportError as e:
    print(f"⚠️  Import error: {e}")
    print("Make sure you're running from project root")


# ============================================================
# Pydantic Models
# ============================================================

class TranscribeRequest(BaseModel):
    audio_base64: str
    language: str = "en"

class SynthesizeRequest(BaseModel):
    text: str
    language: str = "en"
    voice_profile_id: Optional[str] = None
    voice_sample_base64: Optional[str] = None
    emotion: Optional[str] = None  # happy, sad, angry, calm
    speed: float = 1.0

class CloneRequest(BaseModel):
    audio_base64: str
    language: str = "en"
    target_language: Optional[str] = None  # For translation
    voice_profile_id: Optional[str] = None
    enhance_audio: bool = True
    emotion: Optional[str] = None

class EnhanceRequest(BaseModel):
    audio_base64: str
    denoise: bool = True
    normalize: bool = True
    trim_silence: bool = True
    enhance_clarity: bool = True

class AnalyzeRequest(BaseModel):
    audio_base64: str
    text: Optional[str] = None

class ProfileCreateRequest(BaseModel):
    name: str
    description: str = ""
    language: str = "en"
    tags: List[str] = []

class ProfileAddSampleRequest(BaseModel):
    profile_id: str
    audio_base64: str
    sample_name: Optional[str] = None


# ============================================================
# FastAPI App
# ============================================================

app = FastAPI(
    title="Denuel Voice Bridge API",
    description="Voice cloning, transcription, and synthesis API",
    version="1.0.0"
)

# CORS middleware for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global instances (lazy loaded)
_pipeline: Optional[VoiceToTextToVoice] = None
_enhancer: Optional[AudioEnhancer] = None
_analyzer: Optional[VoiceAnalyzer] = None
_profile_manager: Optional[VoiceProfileManager] = None


def get_pipeline() -> VoiceToTextToVoice:
    global _pipeline
    if _pipeline is None:
        _pipeline = VoiceToTextToVoice()
    return _pipeline

def get_enhancer() -> AudioEnhancer:
    global _enhancer
    if _enhancer is None:
        _enhancer = AudioEnhancer()
    return _enhancer

def get_analyzer() -> VoiceAnalyzer:
    global _analyzer
    if _analyzer is None:
        _analyzer = VoiceAnalyzer()
    return _analyzer

def get_profile_manager() -> VoiceProfileManager:
    global _profile_manager
    if _profile_manager is None:
        _profile_manager = VoiceProfileManager()
    return _profile_manager


# ============================================================
# Utility Functions
# ============================================================

def base64_to_audio(b64_string: str, sample_rate: int = 22050) -> np.ndarray:
    """Convert base64 audio to numpy array."""
    audio_bytes = base64.b64decode(b64_string)
    
    # Try to read as WAV first
    try:
        with io.BytesIO(audio_bytes) as bio:
            with wave.open(bio, 'rb') as wf:
                frames = wf.readframes(wf.getnframes())
                audio = np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32767.0
                return audio
    except Exception:
        pass
    
    # Fallback: assume raw float32
    try:
        audio = np.frombuffer(audio_bytes, dtype=np.float32)
        return audio
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid audio format")

def audio_to_base64(audio: np.ndarray, sample_rate: int = 22050) -> str:
    """Convert numpy audio array to base64 WAV."""
    audio_int = (audio * 32767).astype(np.int16)
    
    bio = io.BytesIO()
    with wave.open(bio, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(audio_int.tobytes())
    
    bio.seek(0)
    return base64.b64encode(bio.read()).decode('utf-8')

def audio_to_wav_bytes(audio: np.ndarray, sample_rate: int = 22050) -> bytes:
    """Convert numpy audio to WAV bytes."""
    audio_int = (audio * 32767).astype(np.int16)
    
    bio = io.BytesIO()
    with wave.open(bio, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(audio_int.tobytes())
    
    bio.seek(0)
    return bio.read()


# ============================================================
# API Endpoints
# ============================================================

@app.get("/")
async def root():
    """API health check."""
    return {
        "service": "Denuel Voice Bridge API",
        "version": "1.0.0",
        "status": "running",
        "endpoints": [
            "/transcribe",
            "/synthesize", 
            "/clone",
            "/enhance",
            "/analyze",
            "/profiles",
            "/ws/stream"
        ]
    }

@app.get("/health")
async def health():
    """Health check endpoint."""
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}


# ============================================================
# Transcription Endpoint
# ============================================================

@app.post("/transcribe")
async def transcribe(request: TranscribeRequest):
    """
    Transcribe audio to text using Whisper.
    
    Request:
        - audio_base64: Base64 encoded WAV audio
        - language: Language code (default: en)
    
    Response:
        - text: Transcribed text
        - language: Detected language
        - duration: Audio duration in seconds
    """
    try:
        pipeline = get_pipeline()
        audio = base64_to_audio(request.audio_base64)
        
        # Set language
        pipeline.language = request.language
        
        # Transcribe
        text = pipeline.transcribe(audio)
        
        return {
            "success": True,
            "text": text,
            "language": request.language,
            "duration": len(audio) / 22050
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/transcribe/file")
async def transcribe_file(
    file: UploadFile = File(...),
    language: str = Form("en")
):
    """Transcribe uploaded audio file."""
    try:
        pipeline = get_pipeline()
        
        # Read uploaded file
        content = await file.read()
        
        # Convert to numpy array
        with io.BytesIO(content) as bio:
            with wave.open(bio, 'rb') as wf:
                frames = wf.readframes(wf.getnframes())
                audio = np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32767.0
        
        text = pipeline.transcribe(audio)
        
        return {
            "success": True,
            "text": text,
            "filename": file.filename,
            "duration": len(audio) / 22050
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# Synthesis Endpoint
# ============================================================

@app.post("/synthesize")
async def synthesize(request: SynthesizeRequest):
    """
    Synthesize text to speech using XTTS.
    
    Request:
        - text: Text to synthesize
        - language: Language code (default: en)
        - voice_profile_id: Optional voice profile ID
        - voice_sample_base64: Optional voice sample for cloning
        - emotion: Optional emotion (happy, sad, angry, calm)
        - speed: Speech speed multiplier (default: 1.0)
    
    Response:
        - audio_base64: Base64 encoded WAV audio
        - duration: Audio duration in seconds
    """
    try:
        pipeline = get_pipeline()
        
        # Handle voice sample
        voice_sample_path = None
        
        if request.voice_profile_id:
            # Get sample from profile
            manager = get_profile_manager()
            voice_sample_path = manager.get_best_sample(request.voice_profile_id)
        
        elif request.voice_sample_base64:
            # Use provided sample
            audio = base64_to_audio(request.voice_sample_base64)
            temp_file = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
            audio_int = (audio * 32767).astype(np.int16)
            with wave.open(temp_file.name, 'wb') as wf:
                wf.setnchannels(1)
                wf.setsampwidth(2)
                wf.setframerate(22050)
                wf.writeframes(audio_int.tobytes())
            voice_sample_path = temp_file.name
        
        # Set voice sample
        if voice_sample_path:
            pipeline.voice_sample_path = voice_sample_path
        
        # Modify text for emotion (simple approach)
        text = request.text
        if request.emotion:
            text = apply_emotion_markers(text, request.emotion)
        
        # Synthesize
        audio = pipeline.synthesize(text)
        
        if audio is None:
            raise HTTPException(status_code=500, detail="Synthesis failed")
        
        # Apply speed adjustment if needed
        if request.speed != 1.0:
            audio = adjust_speed(audio, request.speed)
        
        audio_b64 = audio_to_base64(audio)
        
        return {
            "success": True,
            "audio_base64": audio_b64,
            "duration": len(audio) / 22050,
            "text": request.text
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/synthesize/wav")
async def synthesize_wav(request: SynthesizeRequest):
    """Synthesize and return WAV file directly."""
    try:
        pipeline = get_pipeline()
        
        if request.voice_profile_id:
            manager = get_profile_manager()
            voice_sample_path = manager.get_best_sample(request.voice_profile_id)
            if voice_sample_path:
                pipeline.voice_sample_path = voice_sample_path
        
        audio = pipeline.synthesize(request.text)
        
        if audio is None:
            raise HTTPException(status_code=500, detail="Synthesis failed")
        
        wav_bytes = audio_to_wav_bytes(audio)
        
        return StreamingResponse(
            io.BytesIO(wav_bytes),
            media_type="audio/wav",
            headers={"Content-Disposition": "attachment; filename=synthesized.wav"}
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# Clone Endpoint (Full Pipeline)
# ============================================================

@app.post("/clone")
async def clone(request: CloneRequest):
    """
    Full voice cloning pipeline: Transcribe → Synthesize with voice clone.
    
    Request:
        - audio_base64: Input audio to clone
        - language: Source language
        - target_language: Target language for translation (optional)
        - voice_profile_id: Voice profile to use
        - enhance_audio: Whether to enhance input audio
        - emotion: Target emotion
    
    Response:
        - text: Transcribed text
        - audio_base64: Cloned voice audio
        - analysis: Voice analysis results
    """
    try:
        pipeline = get_pipeline()
        enhancer = get_enhancer()
        analyzer = get_analyzer()
        
        # Decode input audio
        audio = base64_to_audio(request.audio_base64)
        
        # Enhance if requested
        if request.enhance_audio:
            audio = enhancer.full_enhance(audio)
        
        # Transcribe
        text = pipeline.transcribe(audio)
        
        if not text:
            raise HTTPException(status_code=400, detail="No speech detected")
        
        # Translation (if target language different)
        output_text = text
        if request.target_language and request.target_language != request.language:
            # For now, just note that translation would happen here
            # You could integrate with a translation API
            output_text = f"[Translation to {request.target_language}]: {text}"
        
        # Apply emotion
        if request.emotion:
            output_text = apply_emotion_markers(output_text, request.emotion)
        
        # Set voice profile
        if request.voice_profile_id:
            manager = get_profile_manager()
            voice_sample = manager.get_best_sample(request.voice_profile_id)
            if voice_sample:
                pipeline.voice_sample_path = voice_sample
        
        # Synthesize
        cloned_audio = pipeline.synthesize(output_text)
        
        if cloned_audio is None:
            raise HTTPException(status_code=500, detail="Synthesis failed")
        
        # Analyze output
        analysis = analyzer.analyze(cloned_audio, output_text)
        
        return {
            "success": True,
            "text": text,
            "output_text": output_text,
            "audio_base64": audio_to_base64(cloned_audio),
            "duration": len(cloned_audio) / 22050,
            "analysis": analysis.to_dict()
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# Enhancement Endpoint
# ============================================================

@app.post("/enhance")
async def enhance(request: EnhanceRequest):
    """
    Enhance audio quality.
    
    Request:
        - audio_base64: Input audio
        - denoise: Apply noise reduction
        - normalize: Normalize volume
        - trim_silence: Trim silence
        - enhance_clarity: Enhance voice clarity
    
    Response:
        - audio_base64: Enhanced audio
        - stats: Before/after statistics
    """
    try:
        enhancer = get_enhancer()
        
        audio = base64_to_audio(request.audio_base64)
        
        # Get before stats
        before_stats = enhancer.get_audio_stats(audio)
        
        # Enhance
        enhanced = enhancer.full_enhance(
            audio,
            denoise=request.denoise,
            normalize=request.normalize,
            trim=request.trim_silence,
            clarity=request.enhance_clarity
        )
        
        # Get after stats
        after_stats = enhancer.get_audio_stats(enhanced)
        
        return {
            "success": True,
            "audio_base64": audio_to_base64(enhanced),
            "duration": len(enhanced) / 22050,
            "stats": {
                "before": before_stats,
                "after": after_stats
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# Analysis Endpoint
# ============================================================

@app.post("/analyze")
async def analyze(request: AnalyzeRequest):
    """
    Analyze voice characteristics.
    
    Request:
        - audio_base64: Audio to analyze
        - text: Optional transcription for speaking rate
    
    Response:
        - analysis: Voice analysis metrics
    """
    try:
        analyzer = get_analyzer()
        
        audio = base64_to_audio(request.audio_base64)
        analysis = analyzer.analyze(audio, request.text)
        
        return {
            "success": True,
            "analysis": analysis.to_dict()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/analyze/compare")
async def analyze_compare(
    audio1_base64: str = Form(...),
    audio2_base64: str = Form(...)
):
    """Compare two voice samples for similarity."""
    try:
        analyzer = get_analyzer()
        
        audio1 = base64_to_audio(audio1_base64)
        audio2 = base64_to_audio(audio2_base64)
        
        result = analyzer.compare_voices(audio1, audio2)
        
        return {
            "success": True,
            "similarity": result.to_dict()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# Profile Management Endpoints
# ============================================================

@app.get("/profiles")
async def list_profiles():
    """List all voice profiles."""
    try:
        manager = get_profile_manager()
        profiles = manager.list_profiles()
        
        return {
            "success": True,
            "count": len(profiles),
            "profiles": [p.to_dict() for p in profiles]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/profiles/{profile_id}")
async def get_profile(profile_id: str):
    """Get a specific voice profile."""
    try:
        manager = get_profile_manager()
        profile = manager.get_profile(profile_id)
        
        if not profile:
            raise HTTPException(status_code=404, detail="Profile not found")
        
        return {
            "success": True,
            "profile": profile.to_dict()
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/profiles")
async def create_profile(request: ProfileCreateRequest):
    """Create a new voice profile."""
    try:
        manager = get_profile_manager()
        profile = manager.create_profile(
            name=request.name,
            description=request.description,
            language=request.language,
            tags=request.tags
        )
        
        return {
            "success": True,
            "profile": profile.to_dict()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/profiles/sample")
async def add_profile_sample(request: ProfileAddSampleRequest):
    """Add a voice sample to a profile."""
    try:
        manager = get_profile_manager()
        
        audio = base64_to_audio(request.audio_base64)
        sample_path = manager.add_sample(
            profile_id=request.profile_id,
            audio=audio,
            name=request.sample_name
        )
        
        return {
            "success": True,
            "sample_path": sample_path
        }
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/profiles/{profile_id}")
async def delete_profile(profile_id: str, delete_files: bool = False):
    """Delete a voice profile."""
    try:
        manager = get_profile_manager()
        manager.delete_profile(profile_id, delete_files=delete_files)
        
        return {"success": True, "message": "Profile deleted"}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============================================================
# WebSocket Streaming
# ============================================================

@app.websocket("/ws/stream")
async def websocket_stream(websocket: WebSocket):
    """
    WebSocket endpoint for real-time voice streaming.
    
    Protocol:
        Client sends: {"type": "audio", "data": "<base64 audio chunk>"}
        Server sends: {"type": "transcription", "text": "..."}
        Server sends: {"type": "synthesis", "audio": "<base64 audio>"}
    """
    await websocket.accept()
    
    pipeline = get_pipeline()
    audio_buffer = []
    
    try:
        while True:
            data = await websocket.receive_json()
            
            msg_type = data.get("type")
            
            if msg_type == "audio":
                # Receive audio chunk
                chunk = base64_to_audio(data.get("data", ""))
                audio_buffer.append(chunk)
                
                # Send acknowledgment
                await websocket.send_json({
                    "type": "ack",
                    "buffer_size": sum(len(c) for c in audio_buffer)
                })
            
            elif msg_type == "process":
                # Process accumulated audio
                if audio_buffer:
                    full_audio = np.concatenate(audio_buffer)
                    
                    # Transcribe
                    text = pipeline.transcribe(full_audio)
                    await websocket.send_json({
                        "type": "transcription",
                        "text": text
                    })
                    
                    # Synthesize
                    if text:
                        cloned = pipeline.synthesize(text)
                        if cloned is not None:
                            await websocket.send_json({
                                "type": "synthesis",
                                "audio": audio_to_base64(cloned),
                                "duration": len(cloned) / 22050
                            })
                    
                    # Clear buffer
                    audio_buffer = []
            
            elif msg_type == "clear":
                audio_buffer = []
                await websocket.send_json({"type": "cleared"})
            
            elif msg_type == "ping":
                await websocket.send_json({"type": "pong"})
    
    except WebSocketDisconnect:
        print("WebSocket client disconnected")
    except Exception as e:
        await websocket.send_json({"type": "error", "message": str(e)})


# ============================================================
# Helper Functions
# ============================================================

def apply_emotion_markers(text: str, emotion: str) -> str:
    """
    Apply emotion markers to text for TTS.
    Note: XTTS doesn't have native emotion support, but we can
    modify text slightly or use this as a placeholder for future models.
    """
    emotion_prefixes = {
        "happy": "(happily) ",
        "sad": "(sadly) ",
        "angry": "(angrily) ",
        "calm": "(calmly) ",
        "excited": "(excitedly) ",
        "whisper": "(whispering) ",
    }
    
    prefix = emotion_prefixes.get(emotion.lower(), "")
    return prefix + text

def adjust_speed(audio: np.ndarray, speed: float, 
                 sample_rate: int = 22050) -> np.ndarray:
    """Adjust audio playback speed."""
    try:
        from scipy import signal
        
        # Calculate new length
        new_length = int(len(audio) / speed)
        
        # Resample
        resampled = signal.resample(audio, new_length)
        return resampled.astype(np.float32)
    except ImportError:
        # Fallback: simple decimation/interpolation
        indices = np.linspace(0, len(audio) - 1, int(len(audio) / speed))
        return np.interp(indices, np.arange(len(audio)), audio).astype(np.float32)


# ============================================================
# Multi-Language Support
# ============================================================

SUPPORTED_LANGUAGES = {
    "en": "English",
    "es": "Spanish",
    "fr": "French",
    "de": "German",
    "it": "Italian",
    "pt": "Portuguese",
    "pl": "Polish",
    "tr": "Turkish",
    "ru": "Russian",
    "nl": "Dutch",
    "cs": "Czech",
    "ar": "Arabic",
    "zh": "Chinese",
    "ja": "Japanese",
    "ko": "Korean",
    "hi": "Hindi"
}

@app.get("/languages")
async def list_languages():
    """List supported languages for XTTS."""
    return {
        "success": True,
        "languages": SUPPORTED_LANGUAGES
    }


# ============================================================
# Main Entry Point
# ============================================================

if __name__ == "__main__":
    import uvicorn
    
    print("\n" + "="*60)
    print("🚀 Starting Denuel Voice Bridge API Server")
    print("="*60)
    print(f"   Docs:      http://localhost:8000/docs")
    print(f"   Health:    http://localhost:8000/health")
    print(f"   WebSocket: ws://localhost:8000/ws/stream")
    print("="*60 + "\n")
    
    uvicorn.run(
        "server:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
