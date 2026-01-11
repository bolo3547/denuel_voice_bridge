"""
Metrics & Monitoring Module
============================
Prometheus metrics, health checks, and observability for Voice Bridge API.
"""

import time
import os
from datetime import datetime
from typing import Dict, Optional, Callable
from functools import wraps
from collections import defaultdict

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware

# Try to import prometheus client
try:
    from prometheus_client import (
        Counter, Histogram, Gauge, Info,
        generate_latest, CONTENT_TYPE_LATEST, REGISTRY
    )
    PROMETHEUS_AVAILABLE = True
except ImportError:
    PROMETHEUS_AVAILABLE = False
    print("prometheus_client not installed. Metrics disabled. Run: pip install prometheus-client")


# =============================================================================
# METRICS DEFINITIONS
# =============================================================================

if PROMETHEUS_AVAILABLE:
    # Request metrics
    REQUEST_COUNT = Counter(
        'voice_bridge_requests_total',
        'Total HTTP requests',
        ['method', 'endpoint', 'status']
    )
    
    REQUEST_LATENCY = Histogram(
        'voice_bridge_request_latency_seconds',
        'HTTP request latency in seconds',
        ['method', 'endpoint'],
        buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0]
    )
    
    REQUEST_IN_PROGRESS = Gauge(
        'voice_bridge_requests_in_progress',
        'Number of requests currently being processed',
        ['method', 'endpoint']
    )
    
    # Model inference metrics
    INFERENCE_COUNT = Counter(
        'voice_bridge_inference_total',
        'Total model inference calls',
        ['model', 'operation']
    )
    
    INFERENCE_LATENCY = Histogram(
        'voice_bridge_inference_latency_seconds',
        'Model inference latency in seconds',
        ['model', 'operation'],
        buckets=[0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0, 120.0]
    )
    
    INFERENCE_ERRORS = Counter(
        'voice_bridge_inference_errors_total',
        'Total model inference errors',
        ['model', 'operation', 'error_type']
    )
    
    # Audio processing metrics
    AUDIO_PROCESSED_BYTES = Counter(
        'voice_bridge_audio_processed_bytes_total',
        'Total bytes of audio processed',
        ['operation']
    )
    
    AUDIO_DURATION_SECONDS = Counter(
        'voice_bridge_audio_duration_seconds_total',
        'Total seconds of audio processed',
        ['operation']
    )
    
    # WebSocket metrics
    WEBSOCKET_CONNECTIONS = Gauge(
        'voice_bridge_websocket_connections',
        'Current number of WebSocket connections'
    )
    
    WEBSOCKET_MESSAGES = Counter(
        'voice_bridge_websocket_messages_total',
        'Total WebSocket messages',
        ['direction']  # 'sent' or 'received'
    )
    
    # Rate limiting metrics
    RATE_LIMIT_HITS = Counter(
        'voice_bridge_rate_limit_hits_total',
        'Total rate limit hits',
        ['identifier_type']  # 'user' or 'ip'
    )
    
    # System metrics
    APP_INFO = Info(
        'voice_bridge_app',
        'Application information'
    )
    APP_INFO.info({
        'version': '1.0.0',
        'python_version': os.sys.version.split()[0]
    })


# =============================================================================
# IN-MEMORY METRICS (fallback when Prometheus not available)
# =============================================================================

class InMemoryMetrics:
    """Simple in-memory metrics when Prometheus is not available."""
    
    def __init__(self):
        self.counters: Dict[str, int] = defaultdict(int)
        self.histograms: Dict[str, list] = defaultdict(list)
        self.gauges: Dict[str, float] = defaultdict(float)
        self.start_time = datetime.utcnow()
    
    def inc_counter(self, name: str, labels: Dict = None, value: int = 1):
        key = f"{name}:{labels}" if labels else name
        self.counters[key] += value
    
    def observe_histogram(self, name: str, value: float, labels: Dict = None):
        key = f"{name}:{labels}" if labels else name
        self.histograms[key].append(value)
        # Keep only last 1000 observations
        if len(self.histograms[key]) > 1000:
            self.histograms[key] = self.histograms[key][-1000:]
    
    def set_gauge(self, name: str, value: float, labels: Dict = None):
        key = f"{name}:{labels}" if labels else name
        self.gauges[key] = value
    
    def get_summary(self) -> Dict:
        """Get summary of all metrics."""
        summary = {
            "uptime_seconds": (datetime.utcnow() - self.start_time).total_seconds(),
            "counters": dict(self.counters),
            "gauges": dict(self.gauges),
            "histograms": {}
        }
        
        for name, values in self.histograms.items():
            if values:
                sorted_values = sorted(values)
                summary["histograms"][name] = {
                    "count": len(values),
                    "sum": sum(values),
                    "avg": sum(values) / len(values),
                    "min": min(values),
                    "max": max(values),
                    "p50": sorted_values[len(values) // 2],
                    "p95": sorted_values[int(len(values) * 0.95)] if len(values) > 1 else sorted_values[0],
                    "p99": sorted_values[int(len(values) * 0.99)] if len(values) > 1 else sorted_values[0]
                }
        
        return summary


# Global fallback metrics
fallback_metrics = InMemoryMetrics()


# =============================================================================
# METRICS HELPER FUNCTIONS
# =============================================================================

def record_request(method: str, endpoint: str, status: int, latency: float):
    """Record HTTP request metrics."""
    if PROMETHEUS_AVAILABLE:
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status=str(status)).inc()
        REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(latency)
    else:
        fallback_metrics.inc_counter("requests_total", {"method": method, "endpoint": endpoint, "status": status})
        fallback_metrics.observe_histogram("request_latency", latency, {"method": method, "endpoint": endpoint})


def record_inference(model: str, operation: str, latency: float, error: str = None):
    """Record model inference metrics."""
    if PROMETHEUS_AVAILABLE:
        INFERENCE_COUNT.labels(model=model, operation=operation).inc()
        INFERENCE_LATENCY.labels(model=model, operation=operation).observe(latency)
        if error:
            INFERENCE_ERRORS.labels(model=model, operation=operation, error_type=error).inc()
    else:
        fallback_metrics.inc_counter("inference_total", {"model": model, "operation": operation})
        fallback_metrics.observe_histogram("inference_latency", latency, {"model": model, "operation": operation})
        if error:
            fallback_metrics.inc_counter("inference_errors", {"model": model, "operation": operation, "error": error})


def record_audio_processed(operation: str, bytes_count: int, duration_seconds: float):
    """Record audio processing metrics."""
    if PROMETHEUS_AVAILABLE:
        AUDIO_PROCESSED_BYTES.labels(operation=operation).inc(bytes_count)
        AUDIO_DURATION_SECONDS.labels(operation=operation).inc(duration_seconds)
    else:
        fallback_metrics.inc_counter("audio_bytes", {"operation": operation}, bytes_count)
        fallback_metrics.inc_counter("audio_duration", {"operation": operation}, int(duration_seconds * 1000))


def record_websocket_connection(connected: bool):
    """Record WebSocket connection."""
    if PROMETHEUS_AVAILABLE:
        if connected:
            WEBSOCKET_CONNECTIONS.inc()
        else:
            WEBSOCKET_CONNECTIONS.dec()
    else:
        current = fallback_metrics.gauges.get("websocket_connections", 0)
        fallback_metrics.set_gauge("websocket_connections", current + (1 if connected else -1))


def record_websocket_message(direction: str):
    """Record WebSocket message (direction: 'sent' or 'received')."""
    if PROMETHEUS_AVAILABLE:
        WEBSOCKET_MESSAGES.labels(direction=direction).inc()
    else:
        fallback_metrics.inc_counter("websocket_messages", {"direction": direction})


def record_rate_limit_hit(is_user: bool):
    """Record rate limit hit."""
    identifier_type = "user" if is_user else "ip"
    if PROMETHEUS_AVAILABLE:
        RATE_LIMIT_HITS.labels(identifier_type=identifier_type).inc()
    else:
        fallback_metrics.inc_counter("rate_limit_hits", {"type": identifier_type})


# =============================================================================
# TIMING DECORATOR
# =============================================================================

def timed_inference(model: str, operation: str):
    """Decorator to time model inference calls."""
    def decorator(func: Callable):
        @wraps(func)
        def wrapper(*args, **kwargs):
            start = time.time()
            error = None
            try:
                result = func(*args, **kwargs)
                return result
            except Exception as e:
                error = type(e).__name__
                raise
            finally:
                latency = time.time() - start
                record_inference(model, operation, latency, error)
        
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            start = time.time()
            error = None
            try:
                result = await func(*args, **kwargs)
                return result
            except Exception as e:
                error = type(e).__name__
                raise
            finally:
                latency = time.time() - start
                record_inference(model, operation, latency, error)
        
        import asyncio
        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        return wrapper
    return decorator


# =============================================================================
# MIDDLEWARE
# =============================================================================

class MetricsMiddleware(BaseHTTPMiddleware):
    """Middleware to record request metrics."""
    
    async def dispatch(self, request: Request, call_next):
        # Skip metrics endpoint itself
        if request.url.path == "/metrics":
            return await call_next(request)
        
        method = request.method
        endpoint = request.url.path
        
        # Track in-progress requests
        if PROMETHEUS_AVAILABLE:
            REQUEST_IN_PROGRESS.labels(method=method, endpoint=endpoint).inc()
        
        start = time.time()
        
        try:
            response = await call_next(request)
            status = response.status_code
        except Exception as e:
            status = 500
            raise
        finally:
            latency = time.time() - start
            record_request(method, endpoint, status, latency)
            
            if PROMETHEUS_AVAILABLE:
                REQUEST_IN_PROGRESS.labels(method=method, endpoint=endpoint).dec()
        
        # Add latency header
        response.headers["X-Response-Time"] = f"{latency:.3f}s"
        
        return response


# =============================================================================
# HEALTH CHECK
# =============================================================================

class HealthChecker:
    """System health checker."""
    
    def __init__(self):
        self.checks: Dict[str, Callable] = {}
        self.start_time = datetime.utcnow()
    
    def register_check(self, name: str, check_func: Callable):
        """Register a health check function."""
        self.checks[name] = check_func
    
    def run_checks(self) -> Dict:
        """Run all health checks and return results."""
        results = {
            "status": "healthy",
            "uptime_seconds": (datetime.utcnow() - self.start_time).total_seconds(),
            "timestamp": datetime.utcnow().isoformat(),
            "checks": {}
        }
        
        all_healthy = True
        
        for name, check_func in self.checks.items():
            try:
                check_result = check_func()
                results["checks"][name] = {
                    "status": "healthy" if check_result else "unhealthy",
                    "details": check_result if isinstance(check_result, dict) else None
                }
                if not check_result:
                    all_healthy = False
            except Exception as e:
                results["checks"][name] = {
                    "status": "unhealthy",
                    "error": str(e)
                }
                all_healthy = False
        
        results["status"] = "healthy" if all_healthy else "unhealthy"
        return results


# Global health checker
health_checker = HealthChecker()


# Default health checks
def check_disk_space():
    """Check available disk space."""
    try:
        import shutil
        total, used, free = shutil.disk_usage("/")
        free_percent = (free / total) * 100
        return {
            "free_percent": round(free_percent, 2),
            "free_gb": round(free / (1024**3), 2),
            "healthy": free_percent > 10
        }
    except:
        return True  # Skip if can't check


def check_memory():
    """Check available memory."""
    try:
        import psutil
        memory = psutil.virtual_memory()
        return {
            "available_percent": round(100 - memory.percent, 2),
            "available_gb": round(memory.available / (1024**3), 2),
            "healthy": memory.percent < 90
        }
    except ImportError:
        return True  # psutil not installed


# Register default checks
health_checker.register_check("disk", check_disk_space)
health_checker.register_check("memory", check_memory)


# =============================================================================
# METRICS ROUTER
# =============================================================================

def create_metrics_router():
    """Create FastAPI router with metrics endpoints."""
    from fastapi import APIRouter
    from fastapi.responses import PlainTextResponse
    
    router = APIRouter(tags=["Monitoring"])
    
    @router.get("/metrics", response_class=PlainTextResponse)
    async def prometheus_metrics():
        """Prometheus metrics endpoint."""
        if PROMETHEUS_AVAILABLE:
            return Response(
                content=generate_latest(REGISTRY),
                media_type=CONTENT_TYPE_LATEST
            )
        else:
            # Return fallback metrics in Prometheus-like format
            metrics = fallback_metrics.get_summary()
            lines = [
                f"# Voice Bridge Metrics (fallback mode)",
                f"voice_bridge_uptime_seconds {metrics['uptime_seconds']:.2f}"
            ]
            for name, value in metrics["counters"].items():
                safe_name = name.replace(":", "_").replace("{", "_").replace("}", "_")
                lines.append(f"voice_bridge_{safe_name} {value}")
            for name, value in metrics["gauges"].items():
                safe_name = name.replace(":", "_").replace("{", "_").replace("}", "_")
                lines.append(f"voice_bridge_{safe_name} {value}")
            return PlainTextResponse("\n".join(lines))
    
    @router.get("/health/live")
    async def liveness():
        """Kubernetes liveness probe."""
        return {"status": "alive"}
    
    @router.get("/health/ready")
    async def readiness():
        """Kubernetes readiness probe."""
        results = health_checker.run_checks()
        if results["status"] != "healthy":
            from fastapi import HTTPException
            raise HTTPException(status_code=503, detail=results)
        return results
    
    @router.get("/health/detailed")
    async def detailed_health():
        """Detailed health check."""
        return health_checker.run_checks()
    
    @router.get("/stats")
    async def get_stats():
        """Get application statistics."""
        if PROMETHEUS_AVAILABLE:
            # Can't easily export Prometheus metrics as JSON
            return {
                "prometheus_enabled": True,
                "message": "Use /metrics endpoint for Prometheus format"
            }
        else:
            return fallback_metrics.get_summary()
    
    return router
