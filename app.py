"""
FastAPI Entrypoint for Denuel Voice Bridge
==========================================
This file serves as the main entrypoint for deployment platforms.
"""

import os
import sys
from pathlib import Path

# Add project root to path
PROJECT_ROOT = Path(__file__).parent
sys.path.insert(0, str(PROJECT_ROOT))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Create a minimal FastAPI app
app = FastAPI(
    title="Denuel Voice Bridge API",
    description="Voice Bridge API Server",
    version="1.0.0"
)

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check endpoint (always available)
@app.get("/")
async def root():
    return {"status": "ok", "service": "Denuel Voice Bridge API"}

@app.get("/health")
async def health():
    return {"status": "ok", "service": "Denuel Voice Bridge API", "version": "1.0.0"}

# Try to import and mount the full API routes
try:
    from ai.api.server import app as full_app
    # Mount all routes from the full app
    for route in full_app.routes:
        if hasattr(route, 'path') and route.path not in ['/', '/health', '/docs', '/openapi.json', '/redoc']:
            app.routes.append(route)
    print("✅ Full API loaded successfully")
except ImportError as e:
    print(f"⚠️ Running in minimal mode: {e}")
    
    @app.get("/status")
    async def status():
        return {
            "status": "minimal",
            "message": "Running in minimal mode - some dependencies not available",
            "error": str(e)
        }

# This allows running with: uvicorn app:app
if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
