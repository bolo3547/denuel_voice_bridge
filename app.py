"""
FastAPI Entrypoint for Denuel Voice Bridge
==========================================
This file serves as the main entrypoint for deployment platforms.
"""

import sys
from pathlib import Path

# Add project root to path
PROJECT_ROOT = Path(__file__).parent
sys.path.insert(0, str(PROJECT_ROOT))

# Import the FastAPI app from the server module
from ai.api.server import app

# This allows running with: uvicorn app:app
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
