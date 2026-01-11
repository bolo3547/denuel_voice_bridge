"""
Webhooks & Async Jobs Module
============================
Background job processing and webhook callbacks for Voice Bridge API.
"""

import os
import json
import uuid
import time
import asyncio
import threading
from datetime import datetime
from typing import Optional, Dict, List, Callable, Any
from pathlib import Path
from enum import Enum
from queue import Queue, Empty
from concurrent.futures import ThreadPoolExecutor

from pydantic import BaseModel
from fastapi import HTTPException, BackgroundTasks

# Try to import httpx for webhook calls
try:
    import httpx
    HTTPX_AVAILABLE = True
except ImportError:
    HTTPX_AVAILABLE = False
    print("httpx not installed. Webhook callbacks disabled. Run: pip install httpx")


# =============================================================================
# CONFIGURATION
# =============================================================================

JOBS_STORAGE_PATH = Path(__file__).parent.parent.parent / "data" / "jobs"
WEBHOOKS_STORAGE_PATH = Path(__file__).parent.parent.parent / "data" / "webhooks.json"
MAX_WORKERS = int(os.environ.get("JOB_WORKERS", "4"))
JOB_TIMEOUT = int(os.environ.get("JOB_TIMEOUT", "300"))  # 5 minutes
WEBHOOK_TIMEOUT = int(os.environ.get("WEBHOOK_TIMEOUT", "30"))
WEBHOOK_RETRIES = int(os.environ.get("WEBHOOK_RETRIES", "3"))


# =============================================================================
# MODELS
# =============================================================================

class JobStatus(str, Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class JobType(str, Enum):
    TRANSCRIBE = "transcribe"
    SYNTHESIZE = "synthesize"
    CLONE = "clone"
    ENHANCE = "enhance"
    ANALYZE = "analyze"
    BATCH = "batch"


class Job(BaseModel):
    id: str
    type: JobType
    status: JobStatus = JobStatus.PENDING
    user_id: Optional[str] = None
    created_at: str
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    progress: int = 0  # 0-100
    input_data: Dict = {}
    result: Optional[Dict] = None
    error: Optional[str] = None
    webhook_url: Optional[str] = None
    metadata: Dict = {}


class WebhookEvent(str, Enum):
    JOB_COMPLETED = "job.completed"
    JOB_FAILED = "job.failed"
    TRANSCRIPTION_READY = "transcription.ready"
    SYNTHESIS_READY = "synthesis.ready"
    PROFILE_CREATED = "profile.created"


class Webhook(BaseModel):
    id: str
    url: str
    user_id: str
    events: List[str]
    secret: Optional[str] = None
    is_active: bool = True
    created_at: str
    last_triggered: Optional[str] = None
    failure_count: int = 0


class WebhookPayload(BaseModel):
    event: str
    timestamp: str
    data: Dict


# =============================================================================
# JOB MANAGER
# =============================================================================

class JobManager:
    """Manages background jobs with persistence."""
    
    def __init__(self, storage_path: Path = JOBS_STORAGE_PATH):
        self.storage_path = storage_path
        self.storage_path.mkdir(parents=True, exist_ok=True)
        self._jobs: Dict[str, Job] = {}
        self._handlers: Dict[JobType, Callable] = {}
        self._executor = ThreadPoolExecutor(max_workers=MAX_WORKERS)
        self._load_jobs()
    
    def _load_jobs(self):
        """Load pending jobs from storage."""
        for job_file in self.storage_path.glob("*.json"):
            try:
                with open(job_file, 'r') as f:
                    job_data = json.load(f)
                    job = Job(**job_data)
                    self._jobs[job.id] = job
            except Exception as e:
                print(f"Error loading job {job_file}: {e}")
    
    def _save_job(self, job: Job):
        """Save job to storage."""
        job_file = self.storage_path / f"{job.id}.json"
        with open(job_file, 'w') as f:
            json.dump(job.model_dump(), f, indent=2)
    
    def _delete_job_file(self, job_id: str):
        """Delete job file from storage."""
        job_file = self.storage_path / f"{job_id}.json"
        if job_file.exists():
            job_file.unlink()
    
    def register_handler(self, job_type: JobType, handler: Callable):
        """Register a handler for a job type."""
        self._handlers[job_type] = handler
    
    def create_job(
        self,
        job_type: JobType,
        input_data: Dict,
        user_id: str = None,
        webhook_url: str = None,
        metadata: Dict = None
    ) -> Job:
        """Create a new job."""
        job = Job(
            id=str(uuid.uuid4()),
            type=job_type,
            user_id=user_id,
            created_at=datetime.utcnow().isoformat(),
            input_data=input_data,
            webhook_url=webhook_url,
            metadata=metadata or {}
        )
        
        self._jobs[job.id] = job
        self._save_job(job)
        
        return job
    
    def get_job(self, job_id: str) -> Optional[Job]:
        """Get a job by ID."""
        return self._jobs.get(job_id)
    
    def list_jobs(self, user_id: str = None, status: JobStatus = None, limit: int = 100) -> List[Job]:
        """List jobs with optional filters."""
        jobs = list(self._jobs.values())
        
        if user_id:
            jobs = [j for j in jobs if j.user_id == user_id]
        
        if status:
            jobs = [j for j in jobs if j.status == status]
        
        # Sort by creation time, newest first
        jobs.sort(key=lambda j: j.created_at, reverse=True)
        
        return jobs[:limit]
    
    def update_job(self, job_id: str, **kwargs):
        """Update job fields."""
        job = self._jobs.get(job_id)
        if job:
            for key, value in kwargs.items():
                if hasattr(job, key):
                    setattr(job, key, value)
            self._save_job(job)
    
    def cancel_job(self, job_id: str) -> bool:
        """Cancel a pending job."""
        job = self._jobs.get(job_id)
        if job and job.status == JobStatus.PENDING:
            job.status = JobStatus.CANCELLED
            job.completed_at = datetime.utcnow().isoformat()
            self._save_job(job)
            return True
        return False
    
    def delete_job(self, job_id: str) -> bool:
        """Delete a completed or cancelled job."""
        job = self._jobs.get(job_id)
        if job and job.status in [JobStatus.COMPLETED, JobStatus.FAILED, JobStatus.CANCELLED]:
            del self._jobs[job_id]
            self._delete_job_file(job_id)
            return True
        return False
    
    async def process_job(self, job_id: str):
        """Process a job asynchronously."""
        job = self._jobs.get(job_id)
        if not job:
            return
        
        handler = self._handlers.get(job.type)
        if not handler:
            job.status = JobStatus.FAILED
            job.error = f"No handler registered for job type: {job.type}"
            job.completed_at = datetime.utcnow().isoformat()
            self._save_job(job)
            return
        
        # Update status
        job.status = JobStatus.PROCESSING
        job.started_at = datetime.utcnow().isoformat()
        self._save_job(job)
        
        try:
            # Run handler in thread pool
            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(
                self._executor,
                handler,
                job.input_data,
                lambda p: self._update_progress(job_id, p)
            )
            
            job.status = JobStatus.COMPLETED
            job.result = result
            job.progress = 100
            
            # Trigger webhook
            if job.webhook_url:
                await webhook_manager.send_webhook(
                    job.webhook_url,
                    WebhookEvent.JOB_COMPLETED,
                    {
                        "job_id": job.id,
                        "type": job.type,
                        "result": result
                    }
                )
        
        except Exception as e:
            job.status = JobStatus.FAILED
            job.error = str(e)
            
            # Trigger failure webhook
            if job.webhook_url:
                await webhook_manager.send_webhook(
                    job.webhook_url,
                    WebhookEvent.JOB_FAILED,
                    {
                        "job_id": job.id,
                        "type": job.type,
                        "error": str(e)
                    }
                )
        
        finally:
            job.completed_at = datetime.utcnow().isoformat()
            self._save_job(job)
    
    def _update_progress(self, job_id: str, progress: int):
        """Update job progress."""
        job = self._jobs.get(job_id)
        if job:
            job.progress = min(100, max(0, progress))
            self._save_job(job)
    
    def submit_job(self, job: Job, background_tasks: BackgroundTasks):
        """Submit a job for background processing."""
        background_tasks.add_task(self.process_job, job.id)


# Global job manager
job_manager = JobManager()


# =============================================================================
# WEBHOOK MANAGER
# =============================================================================

class WebhookManager:
    """Manages webhook subscriptions and deliveries."""
    
    def __init__(self, storage_path: Path = WEBHOOKS_STORAGE_PATH):
        self.storage_path = storage_path
        self._webhooks: Dict[str, Webhook] = {}
        self._load_webhooks()
    
    def _load_webhooks(self):
        """Load webhooks from storage."""
        if self.storage_path.exists():
            try:
                with open(self.storage_path, 'r') as f:
                    data = json.load(f)
                    self._webhooks = {k: Webhook(**v) for k, v in data.items()}
            except Exception as e:
                print(f"Error loading webhooks: {e}")
                self._webhooks = {}
    
    def _save_webhooks(self):
        """Save webhooks to storage."""
        self.storage_path.parent.mkdir(parents=True, exist_ok=True)
        with open(self.storage_path, 'w') as f:
            json.dump({k: v.model_dump() for k, v in self._webhooks.items()}, f, indent=2)
    
    def create_webhook(
        self,
        url: str,
        user_id: str,
        events: List[str],
        secret: str = None
    ) -> Webhook:
        """Create a new webhook subscription."""
        webhook = Webhook(
            id=str(uuid.uuid4()),
            url=url,
            user_id=user_id,
            events=events,
            secret=secret,
            created_at=datetime.utcnow().isoformat()
        )
        
        self._webhooks[webhook.id] = webhook
        self._save_webhooks()
        
        return webhook
    
    def get_webhook(self, webhook_id: str) -> Optional[Webhook]:
        """Get a webhook by ID."""
        return self._webhooks.get(webhook_id)
    
    def list_webhooks(self, user_id: str = None) -> List[Webhook]:
        """List webhooks, optionally filtered by user."""
        webhooks = list(self._webhooks.values())
        if user_id:
            webhooks = [w for w in webhooks if w.user_id == user_id]
        return webhooks
    
    def delete_webhook(self, webhook_id: str) -> bool:
        """Delete a webhook."""
        if webhook_id in self._webhooks:
            del self._webhooks[webhook_id]
            self._save_webhooks()
            return True
        return False
    
    def update_webhook(self, webhook_id: str, **kwargs) -> Optional[Webhook]:
        """Update webhook fields."""
        webhook = self._webhooks.get(webhook_id)
        if webhook:
            for key, value in kwargs.items():
                if hasattr(webhook, key):
                    setattr(webhook, key, value)
            self._save_webhooks()
        return webhook
    
    async def send_webhook(
        self,
        url: str,
        event: WebhookEvent,
        data: Dict,
        secret: str = None
    ) -> bool:
        """Send a webhook to a specific URL."""
        if not HTTPX_AVAILABLE:
            print(f"Webhook skipped (httpx not available): {event} -> {url}")
            return False
        
        payload = WebhookPayload(
            event=event.value,
            timestamp=datetime.utcnow().isoformat(),
            data=data
        )
        
        headers = {
            "Content-Type": "application/json",
            "User-Agent": "VoiceBridge-Webhook/1.0"
        }
        
        # Add signature if secret provided
        if secret:
            import hmac
            import hashlib
            signature = hmac.new(
                secret.encode(),
                json.dumps(payload.model_dump()).encode(),
                hashlib.sha256
            ).hexdigest()
            headers["X-Webhook-Signature"] = f"sha256={signature}"
        
        # Retry logic
        for attempt in range(WEBHOOK_RETRIES):
            try:
                async with httpx.AsyncClient(timeout=WEBHOOK_TIMEOUT) as client:
                    response = await client.post(
                        url,
                        json=payload.model_dump(),
                        headers=headers
                    )
                    
                    if response.status_code < 300:
                        return True
                    
                    print(f"Webhook failed (attempt {attempt + 1}): {response.status_code}")
            
            except Exception as e:
                print(f"Webhook error (attempt {attempt + 1}): {e}")
            
            # Wait before retry
            if attempt < WEBHOOK_RETRIES - 1:
                await asyncio.sleep(2 ** attempt)
        
        return False
    
    async def broadcast_event(self, event: WebhookEvent, data: Dict, user_id: str = None):
        """Broadcast event to all subscribed webhooks."""
        tasks = []
        
        for webhook in self._webhooks.values():
            if not webhook.is_active:
                continue
            
            if user_id and webhook.user_id != user_id:
                continue
            
            if event.value in webhook.events or "*" in webhook.events:
                tasks.append(
                    self.send_webhook(webhook.url, event, data, webhook.secret)
                )
        
        if tasks:
            results = await asyncio.gather(*tasks, return_exceptions=True)
            
            # Update failure counts
            for webhook, result in zip(self._webhooks.values(), results):
                if isinstance(result, Exception) or result is False:
                    webhook.failure_count += 1
                    # Disable webhook after too many failures
                    if webhook.failure_count >= 10:
                        webhook.is_active = False
                else:
                    webhook.failure_count = 0
                    webhook.last_triggered = datetime.utcnow().isoformat()
            
            self._save_webhooks()


# Global webhook manager
webhook_manager = WebhookManager()


# =============================================================================
# JOB ROUTER
# =============================================================================

def create_jobs_router():
    """Create FastAPI router with job endpoints."""
    from fastapi import APIRouter, BackgroundTasks, Depends
    from ai.api.auth import require_auth, get_current_user
    
    router = APIRouter(prefix="/jobs", tags=["Jobs"])
    
    @router.post("/")
    async def create_job(
        job_type: JobType,
        input_data: Dict,
        webhook_url: str = None,
        background_tasks: BackgroundTasks = None,
        user: Dict = Depends(require_auth)
    ):
        """Create a new background job."""
        job = job_manager.create_job(
            job_type=job_type,
            input_data=input_data,
            user_id=user["user_id"],
            webhook_url=webhook_url
        )
        
        # Submit for processing
        job_manager.submit_job(job, background_tasks)
        
        return {
            "job_id": job.id,
            "status": job.status,
            "message": "Job submitted successfully"
        }
    
    @router.get("/{job_id}")
    async def get_job(job_id: str, user: Dict = Depends(require_auth)):
        """Get job status and result."""
        job = job_manager.get_job(job_id)
        
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        
        # Check ownership
        if job.user_id != user["user_id"] and "admin" not in user.get("scopes", []):
            raise HTTPException(status_code=403, detail="Not authorized")
        
        return job.model_dump()
    
    @router.get("/")
    async def list_jobs(
        status: JobStatus = None,
        limit: int = 50,
        user: Dict = Depends(require_auth)
    ):
        """List user's jobs."""
        is_admin = "admin" in user.get("scopes", [])
        jobs = job_manager.list_jobs(
            user_id=None if is_admin else user["user_id"],
            status=status,
            limit=limit
        )
        
        return [j.model_dump() for j in jobs]
    
    @router.post("/{job_id}/cancel")
    async def cancel_job(job_id: str, user: Dict = Depends(require_auth)):
        """Cancel a pending job."""
        job = job_manager.get_job(job_id)
        
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        
        if job.user_id != user["user_id"] and "admin" not in user.get("scopes", []):
            raise HTTPException(status_code=403, detail="Not authorized")
        
        if job_manager.cancel_job(job_id):
            return {"status": "cancelled"}
        else:
            raise HTTPException(status_code=400, detail="Cannot cancel job in current state")
    
    @router.delete("/{job_id}")
    async def delete_job(job_id: str, user: Dict = Depends(require_auth)):
        """Delete a completed job."""
        job = job_manager.get_job(job_id)
        
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        
        if job.user_id != user["user_id"] and "admin" not in user.get("scopes", []):
            raise HTTPException(status_code=403, detail="Not authorized")
        
        if job_manager.delete_job(job_id):
            return {"status": "deleted"}
        else:
            raise HTTPException(status_code=400, detail="Cannot delete job in current state")
    
    return router


# =============================================================================
# WEBHOOK ROUTER
# =============================================================================

def create_webhooks_router():
    """Create FastAPI router with webhook endpoints."""
    from fastapi import APIRouter, Depends
    from ai.api.auth import require_auth
    
    router = APIRouter(prefix="/webhooks", tags=["Webhooks"])
    
    @router.post("/")
    async def create_webhook(
        url: str,
        events: List[str],
        secret: str = None,
        user: Dict = Depends(require_auth)
    ):
        """Create a new webhook subscription."""
        webhook = webhook_manager.create_webhook(
            url=url,
            user_id=user["user_id"],
            events=events,
            secret=secret
        )
        
        return {
            "webhook_id": webhook.id,
            "url": webhook.url,
            "events": webhook.events
        }
    
    @router.get("/")
    async def list_webhooks(user: Dict = Depends(require_auth)):
        """List user's webhook subscriptions."""
        is_admin = "admin" in user.get("scopes", [])
        webhooks = webhook_manager.list_webhooks(
            user_id=None if is_admin else user["user_id"]
        )
        
        return [
            {
                "id": w.id,
                "url": w.url,
                "events": w.events,
                "is_active": w.is_active,
                "failure_count": w.failure_count,
                "last_triggered": w.last_triggered
            }
            for w in webhooks
        ]
    
    @router.delete("/{webhook_id}")
    async def delete_webhook(webhook_id: str, user: Dict = Depends(require_auth)):
        """Delete a webhook subscription."""
        webhook = webhook_manager.get_webhook(webhook_id)
        
        if not webhook:
            raise HTTPException(status_code=404, detail="Webhook not found")
        
        if webhook.user_id != user["user_id"] and "admin" not in user.get("scopes", []):
            raise HTTPException(status_code=403, detail="Not authorized")
        
        webhook_manager.delete_webhook(webhook_id)
        return {"status": "deleted"}
    
    @router.post("/{webhook_id}/test")
    async def test_webhook(webhook_id: str, user: Dict = Depends(require_auth)):
        """Send a test event to a webhook."""
        webhook = webhook_manager.get_webhook(webhook_id)
        
        if not webhook:
            raise HTTPException(status_code=404, detail="Webhook not found")
        
        if webhook.user_id != user["user_id"] and "admin" not in user.get("scopes", []):
            raise HTTPException(status_code=403, detail="Not authorized")
        
        success = await webhook_manager.send_webhook(
            webhook.url,
            WebhookEvent.JOB_COMPLETED,
            {"test": True, "message": "This is a test webhook"},
            webhook.secret
        )
        
        return {"success": success}
    
    return router
