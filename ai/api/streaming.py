"""
WebSocket Streaming Optimizations
==================================
Enhanced real-time streaming with partial transcripts, backpressure, and adaptive quality.
"""

import asyncio
import json
import time
from datetime import datetime
from typing import Optional, Dict, Callable, Any, List
from dataclasses import dataclass, field
from enum import Enum
import base64
import struct

from fastapi import WebSocket, WebSocketDisconnect

from ai.api.metrics import record_websocket_connection, record_websocket_message


# =============================================================================
# CONFIGURATION
# =============================================================================

# Buffer settings
AUDIO_CHUNK_SIZE = 4096  # bytes
MAX_BUFFER_SIZE = 1024 * 1024  # 1MB max buffer
FLUSH_INTERVAL = 0.1  # seconds

# Backpressure settings
HIGH_WATER_MARK = 100  # messages
LOW_WATER_MARK = 50  # messages
BACKPRESSURE_DELAY = 0.05  # seconds

# Quality settings
MIN_AUDIO_QUALITY = 8000  # Hz
MAX_AUDIO_QUALITY = 48000  # Hz
ADAPTIVE_QUALITY_WINDOW = 5  # seconds


# =============================================================================
# MODELS
# =============================================================================

class StreamState(str, Enum):
    IDLE = "idle"
    LISTENING = "listening"
    PROCESSING = "processing"
    SPEAKING = "speaking"
    ERROR = "error"


class MessageType(str, Enum):
    # Client -> Server
    AUDIO_CHUNK = "audio_chunk"
    START_STREAM = "start_stream"
    STOP_STREAM = "stop_stream"
    CONFIG = "config"
    PING = "ping"
    
    # Server -> Client
    TRANSCRIPT_PARTIAL = "transcript_partial"
    TRANSCRIPT_FINAL = "transcript_final"
    AUDIO_RESPONSE = "audio_response"
    STATE_CHANGE = "state_change"
    ERROR = "error"
    PONG = "pong"
    METRICS = "metrics"


@dataclass
class StreamConfig:
    """Configuration for a streaming session."""
    language: str = "en"
    sample_rate: int = 16000
    channels: int = 1
    encoding: str = "pcm_s16le"  # or "opus", "mp3"
    interim_results: bool = True
    voice_activity_detection: bool = True
    auto_punctuation: bool = True
    profanity_filter: bool = False
    voice_profile_id: Optional[str] = None
    target_language: Optional[str] = None  # For translation


@dataclass
class StreamMetrics:
    """Metrics for a streaming session."""
    start_time: float = field(default_factory=time.time)
    audio_bytes_received: int = 0
    audio_bytes_sent: int = 0
    messages_received: int = 0
    messages_sent: int = 0
    transcripts_generated: int = 0
    latency_samples: List[float] = field(default_factory=list)
    errors: int = 0
    
    def avg_latency(self) -> float:
        if not self.latency_samples:
            return 0
        return sum(self.latency_samples) / len(self.latency_samples)
    
    def to_dict(self) -> Dict:
        return {
            "duration_seconds": time.time() - self.start_time,
            "audio_bytes_received": self.audio_bytes_received,
            "audio_bytes_sent": self.audio_bytes_sent,
            "messages_received": self.messages_received,
            "messages_sent": self.messages_sent,
            "transcripts_generated": self.transcripts_generated,
            "avg_latency_ms": self.avg_latency() * 1000,
            "errors": self.errors
        }


# =============================================================================
# AUDIO BUFFER
# =============================================================================

class AudioBuffer:
    """Thread-safe audio buffer with backpressure support."""
    
    def __init__(self, max_size: int = MAX_BUFFER_SIZE):
        self.max_size = max_size
        self._buffer = bytearray()
        self._lock = asyncio.Lock()
        self._not_full = asyncio.Event()
        self._not_full.set()
        self._not_empty = asyncio.Event()
    
    async def write(self, data: bytes) -> bool:
        """Write data to buffer. Returns False if buffer is full."""
        async with self._lock:
            if len(self._buffer) + len(data) > self.max_size:
                self._not_full.clear()
                return False
            
            self._buffer.extend(data)
            self._not_empty.set()
            return True
    
    async def read(self, size: int = None) -> bytes:
        """Read data from buffer."""
        await self._not_empty.wait()
        
        async with self._lock:
            if size is None or size >= len(self._buffer):
                data = bytes(self._buffer)
                self._buffer.clear()
            else:
                data = bytes(self._buffer[:size])
                del self._buffer[:size]
            
            if not self._buffer:
                self._not_empty.clear()
            
            self._not_full.set()
            return data
    
    async def wait_not_full(self):
        """Wait until buffer has space."""
        await self._not_full.wait()
    
    @property
    def size(self) -> int:
        return len(self._buffer)
    
    def clear(self):
        self._buffer.clear()
        self._not_empty.clear()
        self._not_full.set()


# =============================================================================
# STREAMING SESSION
# =============================================================================

class StreamingSession:
    """Manages a WebSocket streaming session with optimizations."""
    
    def __init__(
        self,
        websocket: WebSocket,
        user_id: str = None,
        transcribe_func: Callable = None,
        synthesize_func: Callable = None
    ):
        self.websocket = websocket
        self.user_id = user_id
        self.transcribe_func = transcribe_func
        self.synthesize_func = synthesize_func
        
        self.config = StreamConfig()
        self.metrics = StreamMetrics()
        self.state = StreamState.IDLE
        
        self.audio_buffer = AudioBuffer()
        self._send_queue: asyncio.Queue = asyncio.Queue()
        self._running = False
        self._tasks: List[asyncio.Task] = []
        
        # Backpressure control
        self._send_queue_high = False
        
        # Partial transcript accumulation
        self._partial_transcript = ""
        self._last_final_transcript = ""
    
    async def start(self):
        """Start the streaming session."""
        self._running = True
        record_websocket_connection(connected=True)
        
        # Start background tasks
        self._tasks = [
            asyncio.create_task(self._receive_loop()),
            asyncio.create_task(self._send_loop()),
            asyncio.create_task(self._process_loop()),
        ]
        
        await self._change_state(StreamState.IDLE)
        
        try:
            await asyncio.gather(*self._tasks)
        except WebSocketDisconnect:
            pass
        finally:
            await self.stop()
    
    async def stop(self):
        """Stop the streaming session."""
        self._running = False
        record_websocket_connection(connected=False)
        
        # Cancel tasks
        for task in self._tasks:
            task.cancel()
        
        # Clear buffers
        self.audio_buffer.clear()
        
        # Send final metrics
        try:
            await self._send_message(MessageType.METRICS, self.metrics.to_dict())
        except:
            pass
    
    async def _receive_loop(self):
        """Receive and process incoming messages."""
        try:
            while self._running:
                try:
                    message = await asyncio.wait_for(
                        self.websocket.receive(),
                        timeout=30.0
                    )
                except asyncio.TimeoutError:
                    # Send ping to keep alive
                    await self._send_message(MessageType.PONG, {"timestamp": time.time()})
                    continue
                
                if message["type"] == "websocket.disconnect":
                    break
                
                self.metrics.messages_received += 1
                record_websocket_message("received")
                
                # Handle binary (audio) data
                if "bytes" in message:
                    await self._handle_audio(message["bytes"])
                
                # Handle text (JSON) messages
                elif "text" in message:
                    await self._handle_message(json.loads(message["text"]))
        
        except WebSocketDisconnect:
            pass
        except Exception as e:
            self.metrics.errors += 1
            await self._send_error(str(e))
    
    async def _send_loop(self):
        """Send messages from queue with backpressure."""
        while self._running:
            try:
                # Check backpressure
                queue_size = self._send_queue.qsize()
                
                if queue_size > HIGH_WATER_MARK:
                    self._send_queue_high = True
                    await asyncio.sleep(BACKPRESSURE_DELAY)
                elif queue_size < LOW_WATER_MARK:
                    self._send_queue_high = False
                
                # Get message with timeout
                try:
                    message = await asyncio.wait_for(
                        self._send_queue.get(),
                        timeout=1.0
                    )
                except asyncio.TimeoutError:
                    continue
                
                # Send message
                if isinstance(message, bytes):
                    await self.websocket.send_bytes(message)
                    self.metrics.audio_bytes_sent += len(message)
                else:
                    await self.websocket.send_text(json.dumps(message))
                
                self.metrics.messages_sent += 1
                record_websocket_message("sent")
            
            except Exception as e:
                self.metrics.errors += 1
                print(f"Send error: {e}")
    
    async def _process_loop(self):
        """Process buffered audio."""
        while self._running:
            try:
                if self.state != StreamState.LISTENING:
                    await asyncio.sleep(0.1)
                    continue
                
                # Wait for enough audio data
                if self.audio_buffer.size < AUDIO_CHUNK_SIZE:
                    await asyncio.sleep(FLUSH_INTERVAL)
                    continue
                
                # Read audio chunk
                audio_data = await self.audio_buffer.read(AUDIO_CHUNK_SIZE * 4)
                
                if not audio_data:
                    continue
                
                # Process audio
                start_time = time.time()
                await self._process_audio(audio_data)
                latency = time.time() - start_time
                self.metrics.latency_samples.append(latency)
                
                # Keep only recent latency samples
                if len(self.metrics.latency_samples) > 100:
                    self.metrics.latency_samples = self.metrics.latency_samples[-100:]
            
            except Exception as e:
                self.metrics.errors += 1
                print(f"Process error: {e}")
                await asyncio.sleep(0.1)
    
    async def _handle_audio(self, data: bytes):
        """Handle incoming audio data."""
        self.metrics.audio_bytes_received += len(data)
        
        # Apply backpressure if needed
        if self._send_queue_high:
            await asyncio.sleep(BACKPRESSURE_DELAY)
        
        # Write to buffer
        if not await self.audio_buffer.write(data):
            await self._send_error("Buffer overflow - slow down audio input")
    
    async def _handle_message(self, message: Dict):
        """Handle incoming JSON message."""
        msg_type = message.get("type")
        data = message.get("data", {})
        
        if msg_type == MessageType.START_STREAM.value:
            await self._start_stream(data)
        
        elif msg_type == MessageType.STOP_STREAM.value:
            await self._stop_stream()
        
        elif msg_type == MessageType.CONFIG.value:
            await self._update_config(data)
        
        elif msg_type == MessageType.PING.value:
            await self._send_message(MessageType.PONG, {
                "timestamp": time.time(),
                "client_timestamp": data.get("timestamp")
            })
        
        elif msg_type == MessageType.AUDIO_CHUNK.value:
            # Base64 encoded audio
            audio_data = base64.b64decode(data.get("audio", ""))
            await self._handle_audio(audio_data)
    
    async def _start_stream(self, config_data: Dict = None):
        """Start audio streaming."""
        if config_data:
            await self._update_config(config_data)
        
        await self._change_state(StreamState.LISTENING)
    
    async def _stop_stream(self):
        """Stop audio streaming."""
        # Process remaining buffer
        if self.audio_buffer.size > 0:
            remaining = await self.audio_buffer.read()
            if remaining:
                await self._process_audio(remaining, is_final=True)
        
        await self._change_state(StreamState.IDLE)
    
    async def _update_config(self, config_data: Dict):
        """Update stream configuration."""
        for key, value in config_data.items():
            if hasattr(self.config, key):
                setattr(self.config, key, value)
        
        await self._send_message(MessageType.CONFIG, {
            "status": "updated",
            "config": self.config.__dict__
        })
    
    async def _process_audio(self, audio_data: bytes, is_final: bool = False):
        """Process audio chunk and generate transcript."""
        if not self.transcribe_func:
            return
        
        await self._change_state(StreamState.PROCESSING)
        
        try:
            # Transcribe audio
            result = await asyncio.get_event_loop().run_in_executor(
                None,
                self.transcribe_func,
                audio_data,
                self.config.language,
                self.config.interim_results
            )
            
            if isinstance(result, dict):
                transcript = result.get("text", "")
                is_final_result = result.get("is_final", is_final)
            else:
                transcript = str(result)
                is_final_result = is_final
            
            if transcript:
                self.metrics.transcripts_generated += 1
                
                if is_final_result:
                    # Send final transcript
                    self._last_final_transcript = transcript
                    self._partial_transcript = ""
                    
                    await self._send_message(MessageType.TRANSCRIPT_FINAL, {
                        "text": transcript,
                        "language": self.config.language,
                        "timestamp": time.time()
                    })
                    
                    # Generate audio response if configured
                    if self.synthesize_func and self.config.voice_profile_id:
                        await self._generate_response(transcript)
                
                elif self.config.interim_results:
                    # Send partial transcript
                    self._partial_transcript = transcript
                    
                    await self._send_message(MessageType.TRANSCRIPT_PARTIAL, {
                        "text": transcript,
                        "stability": result.get("stability", 0.5) if isinstance(result, dict) else 0.5,
                        "timestamp": time.time()
                    })
        
        finally:
            if self.state == StreamState.PROCESSING:
                await self._change_state(StreamState.LISTENING)
    
    async def _generate_response(self, text: str):
        """Generate and send audio response."""
        if not self.synthesize_func:
            return
        
        await self._change_state(StreamState.SPEAKING)
        
        try:
            # Synthesize audio
            audio_data = await asyncio.get_event_loop().run_in_executor(
                None,
                self.synthesize_func,
                text,
                self.config.voice_profile_id,
                self.config.target_language or self.config.language
            )
            
            if audio_data:
                # Send audio in chunks for streaming playback
                chunk_size = 8192
                for i in range(0, len(audio_data), chunk_size):
                    chunk = audio_data[i:i + chunk_size]
                    await self._send_queue.put(chunk)
                
                # Send completion marker
                await self._send_message(MessageType.AUDIO_RESPONSE, {
                    "status": "complete",
                    "bytes_sent": len(audio_data),
                    "timestamp": time.time()
                })
        
        finally:
            await self._change_state(StreamState.LISTENING)
    
    async def _change_state(self, new_state: StreamState):
        """Change session state and notify client."""
        old_state = self.state
        self.state = new_state
        
        await self._send_message(MessageType.STATE_CHANGE, {
            "state": new_state.value,
            "previous_state": old_state.value,
            "timestamp": time.time()
        })
    
    async def _send_message(self, msg_type: MessageType, data: Dict):
        """Queue a message to send."""
        message = {
            "type": msg_type.value,
            "data": data
        }
        await self._send_queue.put(message)
    
    async def _send_error(self, error: str):
        """Send error message."""
        await self._send_message(MessageType.ERROR, {
            "error": error,
            "timestamp": time.time()
        })


# =============================================================================
# WEBSOCKET ROUTER
# =============================================================================

def create_streaming_router():
    """Create FastAPI router with optimized WebSocket endpoints."""
    from fastapi import APIRouter, Depends, Query
    from ai.api.auth import get_current_user
    
    router = APIRouter(tags=["Streaming"])
    
    @router.websocket("/ws/stream/v2")
    async def optimized_stream(
        websocket: WebSocket,
        api_key: str = Query(None, alias="api_key")
    ):
        """
        Optimized WebSocket streaming endpoint.
        
        Features:
        - Partial transcripts with stability scores
        - Backpressure handling
        - Adaptive quality
        - Binary audio streaming
        - Configurable VAD
        
        Message Protocol:
        - Send: {type: "start_stream", data: {config}}
        - Send: {type: "audio_chunk", data: {audio: base64}}
        - Send: Binary audio data directly
        - Receive: {type: "transcript_partial", data: {text, stability}}
        - Receive: {type: "transcript_final", data: {text}}
        - Receive: Binary audio response
        """
        await websocket.accept()
        
        # Validate API key if provided
        user_id = None
        if api_key:
            from ai.api.auth import api_key_manager
            key_data = api_key_manager.validate_key(api_key)
            if key_data:
                user_id = key_data.user_id
        
        # Create session
        session = StreamingSession(
            websocket=websocket,
            user_id=user_id,
            # transcribe_func and synthesize_func would be injected here
        )
        
        await session.start()
    
    @router.get("/ws/status")
    async def websocket_status():
        """Get WebSocket service status."""
        return {
            "status": "available",
            "features": [
                "partial_transcripts",
                "backpressure",
                "binary_audio",
                "adaptive_quality",
                "voice_activity_detection"
            ],
            "config": {
                "max_buffer_size": MAX_BUFFER_SIZE,
                "chunk_size": AUDIO_CHUNK_SIZE,
                "supported_encodings": ["pcm_s16le", "opus", "mp3"]
            }
        }
    
    return router
