"""
Authentication & Authorization Module
=====================================
API Key authentication, JWT tokens, and rate limiting for Voice Bridge API.
"""

import os
import time
import hashlib
import secrets
from datetime import datetime, timedelta
from typing import Optional, Dict, List
from functools import wraps
import json
from pathlib import Path

from fastapi import HTTPException, Security, Depends, Request
from fastapi.security import APIKeyHeader, APIKeyQuery, HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel

# Try to import JWT library
try:
    import jwt
    JWT_AVAILABLE = True
except ImportError:
    JWT_AVAILABLE = False
    print("PyJWT not installed. JWT auth disabled. Run: pip install PyJWT")


# =============================================================================
# CONFIGURATION
# =============================================================================

# Secret key for JWT (use env var in production!)
SECRET_KEY = os.environ.get("VOICE_BRIDGE_SECRET_KEY", "dev-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24 hours

# API Keys storage path
API_KEYS_PATH = Path(__file__).parent.parent.parent / "data" / "api_keys.json"

# Rate limiting settings
RATE_LIMIT_REQUESTS = int(os.environ.get("RATE_LIMIT_REQUESTS", "100"))  # requests per window
RATE_LIMIT_WINDOW = int(os.environ.get("RATE_LIMIT_WINDOW", "60"))  # window in seconds


# =============================================================================
# MODELS
# =============================================================================

class APIKey(BaseModel):
    key: str
    name: str
    user_id: str
    created_at: str
    expires_at: Optional[str] = None
    scopes: List[str] = ["read", "write"]
    rate_limit: int = RATE_LIMIT_REQUESTS
    is_active: bool = True


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int


class TokenData(BaseModel):
    user_id: str
    scopes: List[str] = []
    exp: Optional[datetime] = None


class User(BaseModel):
    user_id: str
    email: Optional[str] = None
    name: Optional[str] = None
    plan: str = "free"  # free, pro, enterprise
    is_active: bool = True
    created_at: str
    usage: Dict = {}


# =============================================================================
# API KEY MANAGEMENT
# =============================================================================

class APIKeyManager:
    """Manages API keys storage and validation."""
    
    def __init__(self, storage_path: Path = API_KEYS_PATH):
        self.storage_path = storage_path
        self._keys: Dict[str, APIKey] = {}
        self._load_keys()
    
    def _load_keys(self):
        """Load API keys from storage."""
        if self.storage_path.exists():
            try:
                with open(self.storage_path, 'r') as f:
                    data = json.load(f)
                    self._keys = {k: APIKey(**v) for k, v in data.items()}
            except Exception as e:
                print(f"Error loading API keys: {e}")
                self._keys = {}
        else:
            self._keys = {}
            # Create default admin key if none exist
            self._create_default_admin_key()
    
    def _save_keys(self):
        """Save API keys to storage."""
        self.storage_path.parent.mkdir(parents=True, exist_ok=True)
        with open(self.storage_path, 'w') as f:
            json.dump({k: v.model_dump() for k, v in self._keys.items()}, f, indent=2)
    
    def _create_default_admin_key(self):
        """Create a default admin API key."""
        admin_key = os.environ.get("VOICE_BRIDGE_ADMIN_KEY")
        if not admin_key:
            admin_key = "vb_admin_" + secrets.token_urlsafe(32)
            print(f"Generated admin API key: {admin_key}")
            print("Set VOICE_BRIDGE_ADMIN_KEY env var to use a custom key")
        
        self._keys[admin_key] = APIKey(
            key=admin_key,
            name="Admin Key",
            user_id="admin",
            created_at=datetime.utcnow().isoformat(),
            scopes=["read", "write", "admin"],
            rate_limit=10000
        )
        self._save_keys()
    
    def create_key(self, name: str, user_id: str, scopes: List[str] = None, 
                   rate_limit: int = None, expires_days: int = None) -> APIKey:
        """Create a new API key."""
        key = "vb_" + secrets.token_urlsafe(32)
        
        expires_at = None
        if expires_days:
            expires_at = (datetime.utcnow() + timedelta(days=expires_days)).isoformat()
        
        api_key = APIKey(
            key=key,
            name=name,
            user_id=user_id,
            created_at=datetime.utcnow().isoformat(),
            expires_at=expires_at,
            scopes=scopes or ["read", "write"],
            rate_limit=rate_limit or RATE_LIMIT_REQUESTS
        )
        
        self._keys[key] = api_key
        self._save_keys()
        return api_key
    
    def validate_key(self, key: str) -> Optional[APIKey]:
        """Validate an API key and return it if valid."""
        if key not in self._keys:
            return None
        
        api_key = self._keys[key]
        
        # Check if active
        if not api_key.is_active:
            return None
        
        # Check expiration
        if api_key.expires_at:
            expires = datetime.fromisoformat(api_key.expires_at)
            if datetime.utcnow() > expires:
                return None
        
        return api_key
    
    def revoke_key(self, key: str) -> bool:
        """Revoke an API key."""
        if key in self._keys:
            self._keys[key].is_active = False
            self._save_keys()
            return True
        return False
    
    def list_keys(self, user_id: str = None) -> List[APIKey]:
        """List all API keys, optionally filtered by user."""
        keys = list(self._keys.values())
        if user_id:
            keys = [k for k in keys if k.user_id == user_id]
        return keys


# Global API key manager
api_key_manager = APIKeyManager()


# =============================================================================
# RATE LIMITING
# =============================================================================

class RateLimiter:
    """Simple in-memory rate limiter using sliding window."""
    
    def __init__(self):
        self._requests: Dict[str, List[float]] = {}
    
    def is_allowed(self, identifier: str, limit: int = RATE_LIMIT_REQUESTS, 
                   window: int = RATE_LIMIT_WINDOW) -> tuple[bool, Dict]:
        """Check if request is allowed under rate limit."""
        now = time.time()
        window_start = now - window
        
        # Get or create request list
        if identifier not in self._requests:
            self._requests[identifier] = []
        
        # Remove old requests outside window
        self._requests[identifier] = [
            t for t in self._requests[identifier] if t > window_start
        ]
        
        current_count = len(self._requests[identifier])
        remaining = max(0, limit - current_count)
        reset_time = int(window_start + window)
        
        info = {
            "limit": limit,
            "remaining": remaining,
            "reset": reset_time,
            "window": window
        }
        
        if current_count >= limit:
            return False, info
        
        # Record this request
        self._requests[identifier].append(now)
        info["remaining"] = remaining - 1
        
        return True, info
    
    def get_usage(self, identifier: str, window: int = RATE_LIMIT_WINDOW) -> int:
        """Get current usage count for identifier."""
        now = time.time()
        window_start = now - window
        
        if identifier not in self._requests:
            return 0
        
        return len([t for t in self._requests[identifier] if t > window_start])


# Global rate limiter
rate_limiter = RateLimiter()


# =============================================================================
# JWT TOKEN FUNCTIONS
# =============================================================================

def create_access_token(user_id: str, scopes: List[str] = None, 
                        expires_delta: timedelta = None) -> str:
    """Create a JWT access token."""
    if not JWT_AVAILABLE:
        raise HTTPException(status_code=500, detail="JWT not available")
    
    expires = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    
    payload = {
        "sub": user_id,
        "scopes": scopes or [],
        "exp": expires,
        "iat": datetime.utcnow()
    }
    
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def decode_token(token: str) -> TokenData:
    """Decode and validate a JWT token."""
    if not JWT_AVAILABLE:
        raise HTTPException(status_code=500, detail="JWT not available")
    
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return TokenData(
            user_id=payload.get("sub"),
            scopes=payload.get("scopes", []),
            exp=datetime.fromtimestamp(payload.get("exp"))
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token has expired")
    except jwt.InvalidTokenError as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}")


# =============================================================================
# FASTAPI DEPENDENCIES
# =============================================================================

# Security schemes
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)
api_key_query = APIKeyQuery(name="api_key", auto_error=False)
bearer_scheme = HTTPBearer(auto_error=False)


async def get_api_key(
    api_key_header: str = Security(api_key_header),
    api_key_query: str = Security(api_key_query),
) -> Optional[str]:
    """Extract API key from header or query parameter."""
    return api_key_header or api_key_query


async def get_current_user(
    request: Request,
    api_key: str = Depends(get_api_key),
    bearer: HTTPAuthorizationCredentials = Security(bearer_scheme),
) -> Dict:
    """
    Authenticate user via API key or JWT token.
    Returns user info dict with rate limit info.
    """
    user_info = {
        "user_id": None,
        "scopes": [],
        "rate_limit": RATE_LIMIT_REQUESTS,
        "auth_method": None
    }
    
    # Try API key first
    if api_key:
        key_data = api_key_manager.validate_key(api_key)
        if key_data:
            user_info["user_id"] = key_data.user_id
            user_info["scopes"] = key_data.scopes
            user_info["rate_limit"] = key_data.rate_limit
            user_info["auth_method"] = "api_key"
    
    # Try JWT token
    elif bearer and JWT_AVAILABLE:
        try:
            token_data = decode_token(bearer.credentials)
            user_info["user_id"] = token_data.user_id
            user_info["scopes"] = token_data.scopes
            user_info["auth_method"] = "jwt"
        except HTTPException:
            pass
    
    return user_info


async def require_auth(user: Dict = Depends(get_current_user)) -> Dict:
    """Require authentication - raises 401 if not authenticated."""
    if not user.get("user_id"):
        raise HTTPException(
            status_code=401,
            detail="Authentication required. Provide X-API-Key header or Bearer token.",
            headers={"WWW-Authenticate": "Bearer"}
        )
    return user


async def require_scope(scope: str):
    """Factory to create scope requirement dependency."""
    async def check_scope(user: Dict = Depends(require_auth)) -> Dict:
        if scope not in user.get("scopes", []):
            raise HTTPException(
                status_code=403,
                detail=f"Insufficient permissions. Required scope: {scope}"
            )
        return user
    return check_scope


async def check_rate_limit(request: Request, user: Dict = Depends(get_current_user)):
    """Check rate limit for current request."""
    # Use user_id or IP as identifier
    identifier = user.get("user_id") or request.client.host
    limit = user.get("rate_limit", RATE_LIMIT_REQUESTS)
    
    allowed, info = rate_limiter.is_allowed(identifier, limit=limit)
    
    # Add rate limit headers to response
    request.state.rate_limit_info = info
    
    if not allowed:
        raise HTTPException(
            status_code=429,
            detail="Rate limit exceeded",
            headers={
                "X-RateLimit-Limit": str(info["limit"]),
                "X-RateLimit-Remaining": str(info["remaining"]),
                "X-RateLimit-Reset": str(info["reset"]),
                "Retry-After": str(info["window"])
            }
        )
    
    return user


# =============================================================================
# AUTH ROUTER ENDPOINTS
# =============================================================================

def create_auth_router():
    """Create FastAPI router with auth endpoints."""
    from fastapi import APIRouter
    
    router = APIRouter(prefix="/auth", tags=["Authentication"])
    
    @router.post("/token", response_model=Token)
    async def login_for_token(api_key: str = Depends(get_api_key)):
        """Exchange API key for JWT token."""
        if not api_key:
            raise HTTPException(status_code=401, detail="API key required")
        
        key_data = api_key_manager.validate_key(api_key)
        if not key_data:
            raise HTTPException(status_code=401, detail="Invalid API key")
        
        token = create_access_token(
            user_id=key_data.user_id,
            scopes=key_data.scopes
        )
        
        return Token(
            access_token=token,
            expires_in=ACCESS_TOKEN_EXPIRE_MINUTES * 60
        )
    
    @router.get("/me")
    async def get_current_user_info(user: Dict = Depends(require_auth)):
        """Get current authenticated user info."""
        return {
            "user_id": user["user_id"],
            "scopes": user["scopes"],
            "auth_method": user["auth_method"]
        }
    
    @router.post("/keys", dependencies=[Depends(require_auth)])
    async def create_api_key(
        name: str,
        scopes: List[str] = None,
        expires_days: int = None,
        user: Dict = Depends(require_auth)
    ):
        """Create a new API key (requires admin scope or own user)."""
        # Only admins can create keys for others
        if "admin" not in user.get("scopes", []):
            scopes = ["read", "write"]  # Non-admins get limited scopes
        
        new_key = api_key_manager.create_key(
            name=name,
            user_id=user["user_id"],
            scopes=scopes,
            expires_days=expires_days
        )
        
        return {
            "key": new_key.key,
            "name": new_key.name,
            "scopes": new_key.scopes,
            "expires_at": new_key.expires_at
        }
    
    @router.get("/keys")
    async def list_api_keys(user: Dict = Depends(require_auth)):
        """List API keys for current user."""
        is_admin = "admin" in user.get("scopes", [])
        keys = api_key_manager.list_keys(
            user_id=None if is_admin else user["user_id"]
        )
        
        # Don't expose full key values
        return [
            {
                "key": k.key[:10] + "...",
                "name": k.name,
                "user_id": k.user_id,
                "scopes": k.scopes,
                "is_active": k.is_active,
                "created_at": k.created_at,
                "expires_at": k.expires_at
            }
            for k in keys
        ]
    
    @router.delete("/keys/{key_prefix}")
    async def revoke_api_key(key_prefix: str, user: Dict = Depends(require_auth)):
        """Revoke an API key by its prefix."""
        # Find key by prefix
        for key in api_key_manager._keys:
            if key.startswith(key_prefix):
                key_data = api_key_manager._keys[key]
                # Check ownership or admin
                if key_data.user_id != user["user_id"] and "admin" not in user.get("scopes", []):
                    raise HTTPException(status_code=403, detail="Not authorized to revoke this key")
                
                api_key_manager.revoke_key(key)
                return {"status": "revoked", "key": key[:10] + "..."}
        
        raise HTTPException(status_code=404, detail="API key not found")
    
    @router.get("/rate-limit")
    async def get_rate_limit_status(
        request: Request,
        user: Dict = Depends(get_current_user)
    ):
        """Get current rate limit status."""
        identifier = user.get("user_id") or request.client.host
        limit = user.get("rate_limit", RATE_LIMIT_REQUESTS)
        usage = rate_limiter.get_usage(identifier)
        
        return {
            "limit": limit,
            "used": usage,
            "remaining": max(0, limit - usage),
            "window_seconds": RATE_LIMIT_WINDOW
        }
    
    return router
