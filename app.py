"""
FastAPI Entrypoint for Denuel Voice Bridge
==========================================
This file serves as the main entrypoint for deployment platforms.

Features:
- API Key Authentication & JWT
- Rate Limiting
- Prometheus Metrics
- Background Jobs & Webhooks
- Usage Tracking & Billing
- Admin Dashboard
- WebSocket Streaming
"""

import os
import sys
from pathlib import Path

# Ensure stdout/stderr use UTF-8 to avoid UnicodeEncodeError on Windows consoles
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
if hasattr(sys.stderr, "reconfigure"):
    try:
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

# Add project root to path
PROJECT_ROOT = Path(__file__).parent
sys.path.insert(0, str(PROJECT_ROOT))

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

# Create the main FastAPI app
app = FastAPI(
    title="Denuel Voice Bridge API",
    description="Voice cloning, transcription, and synthesis API with Pro Max features",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add metrics middleware
try:
    from ai.api.metrics import MetricsMiddleware, create_metrics_router
    app.add_middleware(MetricsMiddleware)
    app.include_router(create_metrics_router())
    print("[OK] Metrics middleware loaded")
except ImportError as e:
    print(f"[WARN] Metrics not available: {e}")

# Health check endpoints (always available)
@app.get("/", tags=["Health"])
async def root():
    return {
        "status": "ok",
        "service": "Denuel Voice Bridge API",
        "version": "2.0.0",
        "features": ["auth", "rate-limiting", "metrics", "jobs", "webhooks", "billing", "admin"]
    }

@app.get("/health", tags=["Health"])
async def health():
    return {
        "status": "ok",
        "service": "Denuel Voice Bridge API",
        "version": "2.0.0"
    }

# Load authentication router
try:
    from ai.api.auth import create_auth_router, check_rate_limit
    app.include_router(create_auth_router())
    print("[OK] Auth router loaded")
except ImportError as e:
    print(f"[WARN] Auth not available: {e}")

# Load jobs router
try:
    from ai.api.jobs import create_jobs_router, create_webhooks_router
    app.include_router(create_jobs_router())
    app.include_router(create_webhooks_router())
    print("[OK] Jobs & Webhooks routers loaded")
except ImportError as e:
    print(f"[WARN] Jobs/Webhooks not available: {e}")

# Load billing router
try:
    from ai.api.billing import create_billing_router
    app.include_router(create_billing_router())
    print("[OK] Billing router loaded")
except ImportError as e:
    print(f"[WARN] Billing not available: {e}")

# Load admin router
try:
    from ai.api.admin import create_admin_router
    app.include_router(create_admin_router())
    print("[OK] Admin router loaded")
except ImportError as e:
    print(f"[WARN] Admin not available: {e}")

# Load streaming router
try:
    from ai.api.streaming import create_streaming_router
    app.include_router(create_streaming_router())
    print("[OK] Streaming router loaded")
except ImportError as e:
    print(f"[WARN] Streaming not available: {e}")

# Load the full voice API routes
try:
    from ai.api.server import app as full_app
    # Mount all routes from the full app
    for route in full_app.routes:
        if hasattr(route, 'path') and route.path not in ['/', '/health', '/docs', '/openapi.json', '/redoc']:
            app.routes.append(route)
    print("[OK] Full Voice API loaded")
except ImportError as e:
    print(f"[WARN] Voice API not available (ML dependencies): {e}")
    
    @app.get("/status", tags=["Health"])
    async def status():
        return {
            "status": "minimal",
            "message": "Running in minimal mode - ML dependencies not available",
            "available_features": ["auth", "jobs", "webhooks", "billing", "admin"]
        }

# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "error": str(exc) if os.environ.get("DEBUG") else "An error occurred"
        }
    )

# Add rate limit headers to responses
@app.middleware("http")
async def add_rate_limit_headers(request: Request, call_next):
    response = await call_next(request)
    
    # Add rate limit info if available
    if hasattr(request.state, 'rate_limit_info'):
        info = request.state.rate_limit_info
        response.headers["X-RateLimit-Limit"] = str(info.get("limit", 0))
        response.headers["X-RateLimit-Remaining"] = str(info.get("remaining", 0))
        response.headers["X-RateLimit-Reset"] = str(info.get("reset", 0))
    
    return response

# This allows running with: uvicorn app:app
if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    host = os.environ.get("HOST", "0.0.0.0")
    reload = os.environ.get("DEBUG", "").lower() == "true"
    
    print(f"Starting Denuel Voice Bridge API on {host}:{port}")
    uvicorn.run(app, host=host, port=port, reload=reload)
