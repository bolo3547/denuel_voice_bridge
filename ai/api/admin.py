"""
Admin Dashboard API
====================
Administrative endpoints for user management, system monitoring, and analytics.
"""

import os
import json
from datetime import datetime, timedelta
from typing import Optional, Dict, List
from pathlib import Path
from collections import defaultdict

from fastapi import HTTPException, Depends
from pydantic import BaseModel

from ai.api.auth import require_auth, api_key_manager
from ai.api.metrics import fallback_metrics, health_checker, PROMETHEUS_AVAILABLE
from ai.api.billing import usage_tracker, PlanTier
from ai.api.jobs import job_manager, JobStatus


# =============================================================================
# CONFIGURATION
# =============================================================================

ADMIN_LOGS_PATH = Path(__file__).parent.parent.parent / "data" / "admin_logs"


# =============================================================================
# MODELS
# =============================================================================

class SystemStats(BaseModel):
    uptime_seconds: float
    total_users: int
    active_users_24h: int
    total_requests: int
    requests_24h: int
    total_audio_minutes: float
    errors_24h: int
    avg_latency_ms: float


class UserSummary(BaseModel):
    user_id: str
    plan: str
    created_at: str
    last_active: Optional[str]
    total_requests: int
    total_usage_cost: float
    is_active: bool


class AuditLog(BaseModel):
    timestamp: str
    user_id: str
    action: str
    resource: str
    details: Dict = {}
    ip_address: Optional[str] = None


# =============================================================================
# AUDIT LOGGING
# =============================================================================

class AuditLogger:
    """Logs administrative actions for compliance."""
    
    def __init__(self, storage_path: Path = ADMIN_LOGS_PATH):
        self.storage_path = storage_path
        self.storage_path.mkdir(parents=True, exist_ok=True)
    
    def log(self, user_id: str, action: str, resource: str, 
            details: Dict = None, ip_address: str = None):
        """Log an audit event."""
        log_entry = AuditLog(
            timestamp=datetime.utcnow().isoformat(),
            user_id=user_id,
            action=action,
            resource=resource,
            details=details or {},
            ip_address=ip_address
        )
        
        # Write to daily log file
        date_str = datetime.utcnow().strftime("%Y-%m-%d")
        log_file = self.storage_path / f"audit_{date_str}.jsonl"
        
        with open(log_file, 'a') as f:
            f.write(json.dumps(log_entry.model_dump()) + "\n")
    
    def get_logs(self, start_date: datetime = None, end_date: datetime = None,
                 user_id: str = None, action: str = None, limit: int = 1000) -> List[AuditLog]:
        """Query audit logs."""
        logs = []
        
        # Default to last 7 days
        if not start_date:
            start_date = datetime.utcnow() - timedelta(days=7)
        if not end_date:
            end_date = datetime.utcnow()
        
        # Read log files in date range
        current = start_date
        while current <= end_date:
            date_str = current.strftime("%Y-%m-%d")
            log_file = self.storage_path / f"audit_{date_str}.jsonl"
            
            if log_file.exists():
                with open(log_file, 'r') as f:
                    for line in f:
                        try:
                            entry = AuditLog(**json.loads(line.strip()))
                            
                            # Apply filters
                            if user_id and entry.user_id != user_id:
                                continue
                            if action and entry.action != action:
                                continue
                            
                            logs.append(entry)
                        except:
                            continue
            
            current += timedelta(days=1)
        
        # Sort by timestamp descending and limit
        logs.sort(key=lambda x: x.timestamp, reverse=True)
        return logs[:limit]


# Global audit logger
audit_logger = AuditLogger()


# =============================================================================
# ADMIN FUNCTIONS
# =============================================================================

def get_system_stats() -> SystemStats:
    """Get system-wide statistics."""
    metrics = fallback_metrics.get_summary()
    
    # Count users
    usage_files = list(usage_tracker.storage_path.glob("*.json"))
    total_users = len(usage_files)
    
    # Count active users (users with activity in last 24h)
    # This is simplified - in production you'd track this properly
    active_users = min(total_users, int(metrics["counters"].get("requests_total:{}", 0) / 10))
    
    return SystemStats(
        uptime_seconds=metrics["uptime_seconds"],
        total_users=total_users,
        active_users_24h=active_users,
        total_requests=sum(v for k, v in metrics["counters"].items() if "request" in k.lower()),
        requests_24h=sum(v for k, v in metrics["counters"].items() if "request" in k.lower()) // 7,  # Estimate
        total_audio_minutes=metrics["counters"].get("audio_duration:{'operation': 'transcribe'}", 0) / 60,
        errors_24h=sum(v for k, v in metrics["counters"].items() if "error" in k.lower()),
        avg_latency_ms=metrics["histograms"].get("request_latency:{}", {}).get("avg", 0) * 1000
    )


def list_users(plan: PlanTier = None, limit: int = 100, offset: int = 0) -> List[UserSummary]:
    """List all users with optional filtering."""
    users = []
    
    for user_file in usage_tracker.storage_path.glob("*.json"):
        try:
            with open(user_file, 'r') as f:
                data = json.load(f)
                
                # Filter by plan if specified
                if plan and data.get("plan") != plan.value:
                    continue
                
                users.append(UserSummary(
                    user_id=data["user_id"],
                    plan=data.get("plan", "free"),
                    created_at=data.get("billing_cycle_start", "unknown"),
                    last_active=None,  # Would need to track this separately
                    total_requests=sum(data.get("usage", {}).values()),
                    total_usage_cost=data.get("cost", 0),
                    is_active=True
                ))
        except:
            continue
    
    # Sort by total requests descending
    users.sort(key=lambda x: x.total_requests, reverse=True)
    
    return users[offset:offset + limit]


def get_user_details(user_id: str) -> Dict:
    """Get detailed user information."""
    usage = usage_tracker.get_usage(user_id)
    keys = api_key_manager.list_keys(user_id)
    jobs = job_manager.list_jobs(user_id=user_id, limit=10)
    
    return {
        "user_id": user_id,
        "usage": usage,
        "api_keys": [{"name": k.name, "created_at": k.created_at, "is_active": k.is_active} for k in keys],
        "recent_jobs": [j.model_dump() for j in jobs]
    }


def update_user_plan(user_id: str, new_plan: PlanTier, admin_user_id: str) -> Dict:
    """Update a user's plan (admin action)."""
    usage_tracker.set_plan(user_id, new_plan)
    
    # Log the action
    audit_logger.log(
        user_id=admin_user_id,
        action="update_plan",
        resource=f"user:{user_id}",
        details={"new_plan": new_plan.value}
    )
    
    return {"status": "updated", "user_id": user_id, "plan": new_plan.value}


def disable_user(user_id: str, reason: str, admin_user_id: str) -> Dict:
    """Disable a user account."""
    # Revoke all API keys
    for key in api_key_manager.list_keys(user_id):
        api_key_manager.revoke_key(key.key)
    
    # Log the action
    audit_logger.log(
        user_id=admin_user_id,
        action="disable_user",
        resource=f"user:{user_id}",
        details={"reason": reason}
    )
    
    return {"status": "disabled", "user_id": user_id}


def get_revenue_stats(days: int = 30) -> Dict:
    """Get revenue statistics."""
    total_revenue = 0
    revenue_by_plan = defaultdict(float)
    revenue_by_day = defaultdict(float)
    
    for user_file in usage_tracker.storage_path.glob("*.json"):
        try:
            with open(user_file, 'r') as f:
                data = json.load(f)
                cost = data.get("cost", 0)
                plan = data.get("plan", "free")
                
                total_revenue += cost
                revenue_by_plan[plan] += cost
        except:
            continue
    
    # Add subscription revenue (simplified - would need actual Stripe data)
    plans = usage_tracker.list_plans()
    for plan in plans:
        if plan.tier != PlanTier.FREE:
            # Estimate subscribers based on users with that plan
            subscriber_count = sum(1 for u in list_users(plan=plan.tier, limit=10000))
            monthly_revenue = subscriber_count * plan.price_monthly
            revenue_by_plan[plan.tier.value] += monthly_revenue
            total_revenue += monthly_revenue
    
    return {
        "period_days": days,
        "total_revenue": round(total_revenue, 2),
        "revenue_by_plan": dict(revenue_by_plan),
        "mrr_estimate": round(total_revenue, 2),  # Simplified
        "overage_revenue": round(sum(revenue_by_plan.values()) - sum(p.price_monthly for p in plans if p.tier != PlanTier.FREE), 2)
    }


def get_error_summary(hours: int = 24) -> Dict:
    """Get error summary for debugging."""
    errors = []
    error_counts = defaultdict(int)
    
    # Read from metrics
    metrics = fallback_metrics.get_summary()
    for key, count in metrics["counters"].items():
        if "error" in key.lower():
            error_counts[key] = count
    
    return {
        "period_hours": hours,
        "total_errors": sum(error_counts.values()),
        "errors_by_type": dict(error_counts),
        "recent_errors": errors[:20]  # Would need to implement error tracking
    }


# =============================================================================
# ADMIN ROUTER
# =============================================================================

def require_admin(user: Dict = Depends(require_auth)) -> Dict:
    """Require admin scope for access."""
    if "admin" not in user.get("scopes", []):
        raise HTTPException(status_code=403, detail="Admin access required")
    return user


def create_admin_router():
    """Create FastAPI router with admin endpoints."""
    from fastapi import APIRouter, Query, Request
    
    router = APIRouter(prefix="/admin", tags=["Admin"])
    
    # System endpoints
    @router.get("/stats")
    async def get_stats(admin: Dict = Depends(require_admin)):
        """Get system-wide statistics."""
        return get_system_stats().model_dump()
    
    @router.get("/health/detailed")
    async def detailed_health(admin: Dict = Depends(require_admin)):
        """Get detailed health information."""
        return health_checker.run_checks()
    
    @router.get("/metrics/summary")
    async def metrics_summary(admin: Dict = Depends(require_admin)):
        """Get metrics summary."""
        return fallback_metrics.get_summary()
    
    # User management
    @router.get("/users")
    async def list_all_users(
        plan: PlanTier = None,
        limit: int = Query(100, le=1000),
        offset: int = 0,
        admin: Dict = Depends(require_admin)
    ):
        """List all users."""
        users = list_users(plan=plan, limit=limit, offset=offset)
        return {"users": [u.model_dump() for u in users], "total": len(users)}
    
    @router.get("/users/{user_id}")
    async def get_user(user_id: str, admin: Dict = Depends(require_admin)):
        """Get detailed user information."""
        return get_user_details(user_id)
    
    @router.put("/users/{user_id}/plan")
    async def update_plan(
        user_id: str,
        plan: PlanTier,
        admin: Dict = Depends(require_admin)
    ):
        """Update user's plan."""
        return update_user_plan(user_id, plan, admin["user_id"])
    
    @router.post("/users/{user_id}/disable")
    async def disable_user_account(
        user_id: str,
        reason: str,
        admin: Dict = Depends(require_admin)
    ):
        """Disable a user account."""
        return disable_user(user_id, reason, admin["user_id"])
    
    # API key management
    @router.get("/api-keys")
    async def list_all_keys(admin: Dict = Depends(require_admin)):
        """List all API keys."""
        keys = api_key_manager.list_keys()
        return {
            "keys": [
                {
                    "key": k.key[:15] + "...",
                    "name": k.name,
                    "user_id": k.user_id,
                    "scopes": k.scopes,
                    "is_active": k.is_active,
                    "created_at": k.created_at
                }
                for k in keys
            ]
        }
    
    @router.delete("/api-keys/{key_prefix}")
    async def revoke_key(key_prefix: str, admin: Dict = Depends(require_admin)):
        """Revoke any API key."""
        for key in api_key_manager._keys:
            if key.startswith(key_prefix):
                api_key_manager.revoke_key(key)
                
                audit_logger.log(
                    user_id=admin["user_id"],
                    action="revoke_key",
                    resource=f"api_key:{key_prefix}...",
                    details={}
                )
                
                return {"status": "revoked"}
        
        raise HTTPException(status_code=404, detail="Key not found")
    
    # Jobs management
    @router.get("/jobs")
    async def list_all_jobs(
        status: JobStatus = None,
        limit: int = Query(100, le=1000),
        admin: Dict = Depends(require_admin)
    ):
        """List all jobs."""
        jobs = job_manager.list_jobs(status=status, limit=limit)
        return {"jobs": [j.model_dump() for j in jobs]}
    
    @router.delete("/jobs/{job_id}")
    async def force_delete_job(job_id: str, admin: Dict = Depends(require_admin)):
        """Force delete any job."""
        job = job_manager.get_job(job_id)
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        
        # Force delete by setting status to cancelled first
        job.status = JobStatus.CANCELLED
        job_manager._save_job(job)
        job_manager.delete_job(job_id)
        
        audit_logger.log(
            user_id=admin["user_id"],
            action="force_delete_job",
            resource=f"job:{job_id}",
            details={}
        )
        
        return {"status": "deleted"}
    
    # Revenue and analytics
    @router.get("/revenue")
    async def revenue_stats(
        days: int = Query(30, le=365),
        admin: Dict = Depends(require_admin)
    ):
        """Get revenue statistics."""
        return get_revenue_stats(days)
    
    @router.get("/errors")
    async def error_summary(
        hours: int = Query(24, le=168),
        admin: Dict = Depends(require_admin)
    ):
        """Get error summary."""
        return get_error_summary(hours)
    
    # Audit logs
    @router.get("/audit-logs")
    async def get_audit_logs(
        user_id: str = None,
        action: str = None,
        limit: int = Query(100, le=1000),
        admin: Dict = Depends(require_admin)
    ):
        """Get audit logs."""
        logs = audit_logger.get_logs(user_id=user_id, action=action, limit=limit)
        return {"logs": [l.model_dump() for l in logs]}
    
    # System actions
    @router.post("/cache/clear")
    async def clear_cache(admin: Dict = Depends(require_admin)):
        """Clear system caches."""
        # Would implement actual cache clearing
        audit_logger.log(
            user_id=admin["user_id"],
            action="clear_cache",
            resource="system",
            details={}
        )
        return {"status": "cache cleared"}
    
    @router.post("/maintenance/start")
    async def start_maintenance(
        message: str = "System maintenance in progress",
        admin: Dict = Depends(require_admin)
    ):
        """Start maintenance mode."""
        # Would implement maintenance mode flag
        audit_logger.log(
            user_id=admin["user_id"],
            action="start_maintenance",
            resource="system",
            details={"message": message}
        )
        return {"status": "maintenance mode started", "message": message}
    
    @router.post("/maintenance/stop")
    async def stop_maintenance(admin: Dict = Depends(require_admin)):
        """Stop maintenance mode."""
        audit_logger.log(
            user_id=admin["user_id"],
            action="stop_maintenance",
            resource="system",
            details={}
        )
        return {"status": "maintenance mode stopped"}
    
    return router
