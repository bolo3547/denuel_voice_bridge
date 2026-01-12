"""
Vercel Serverless Entry Point
=============================
Simplified entry point for Vercel deployment.
"""

import os
import sys
from pathlib import Path

# Ensure stdout/stderr use UTF-8
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

# Add project root to path
PROJECT_ROOT = Path(__file__).parent
sys.path.insert(0, str(PROJECT_ROOT))

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

# Create FastAPI app
app = FastAPI(
    title="Denuel Voice Bridge API",
    description="Voice cloning, transcription, and synthesis API",
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

# Health endpoints
@app.get("/", tags=["Health"])
async def root():
    return {
        "status": "ok",
        "service": "Denuel Voice Bridge API",
        "version": "2.0.0",
        "platform": "vercel"
    }

@app.get("/health", tags=["Health"])
async def health():
    return {"status": "ok", "version": "2.0.0"}

# Try to load auth router
try:
    from ai.api.auth import create_auth_router
    app.include_router(create_auth_router())
except Exception as e:
    print(f"Auth not loaded: {e}")

# Try to load billing router
try:
    from ai.api.billing import create_billing_router
    app.include_router(create_billing_router())
except Exception as e:
    print(f"Billing not loaded: {e}")

# Try to load jobs router
try:
    from ai.api.jobs import create_jobs_router, create_webhooks_router
    app.include_router(create_jobs_router())
    app.include_router(create_webhooks_router())
except Exception as e:
    print(f"Jobs not loaded: {e}")

# Try to load admin router
try:
    from ai.api.admin import create_admin_router
    app.include_router(create_admin_router())
except Exception as e:
    print(f"Admin not loaded: {e}")

# Exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={"detail": str(exc)}
    )

# Vercel handler
handler = app
