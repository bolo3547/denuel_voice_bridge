"""
Vercel Serverless Entry Point
=============================
Simplified entry point for Vercel deployment.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Create FastAPI app
app = FastAPI(
    title="Denuel Voice Bridge API",
    description="Voice cloning, transcription, and synthesis API",
    version="2.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc"
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
@app.get("/api")
@app.get("/api/")
async def root():
    return {
        "status": "ok",
        "service": "Denuel Voice Bridge API",
        "version": "2.0.0",
        "platform": "vercel",
        "endpoints": ["/api/health", "/api/docs", "/api/auth/token", "/api/billing/plans"]
    }

@app.get("/api/health")
async def health():
    return {"status": "ok", "version": "2.0.0"}

@app.get("/api/billing/plans")
async def get_plans():
    return [
        {"tier": "free", "name": "Free", "price": 0, "limits": {"transcribe": 60, "synthesize": 10000}},
        {"tier": "pro", "name": "Pro", "price": 29.99, "limits": {"transcribe": 600, "synthesize": 100000}},
        {"tier": "enterprise", "name": "Enterprise", "price": 299.99, "limits": {"transcribe": 6000, "synthesize": 1000000}}
    ]

@app.post("/api/auth/token")
async def get_token():
    return {"message": "API key authentication - provide X-API-Key header", "token_type": "bearer"}

@app.get("/api/billing/usage")
async def get_usage():
    return {
        "user_id": "demo",
        "plan": "free",
        "usage": {
            "transcribe": {"used": 0, "limit": 60, "remaining": 60},
            "synthesize": {"used": 0, "limit": 10000, "remaining": 10000}
        }
    }

# Vercel handler
handler = app
