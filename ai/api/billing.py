"""
Usage Analytics & Billing Module
=================================
Track API usage, compute costs, and integrate with billing providers.
"""

import os
import json
from datetime import datetime, timedelta
from typing import Optional, Dict, List
from pathlib import Path
from collections import defaultdict
from enum import Enum

from pydantic import BaseModel

# Try to import stripe for billing
try:
    import stripe
    STRIPE_AVAILABLE = True
    stripe.api_key = os.environ.get("STRIPE_API_KEY", "")
except ImportError:
    STRIPE_AVAILABLE = False
    print("stripe not installed. Billing disabled. Run: pip install stripe")


# =============================================================================
# CONFIGURATION
# =============================================================================

USAGE_STORAGE_PATH = Path(__file__).parent.parent.parent / "data" / "usage"
PLANS_CONFIG_PATH = Path(__file__).parent.parent.parent / "data" / "plans.json"

# Pricing per unit (configurable via env vars)
PRICE_PER_TRANSCRIBE_MINUTE = float(os.environ.get("PRICE_TRANSCRIBE_MIN", "0.006"))
PRICE_PER_SYNTHESIS_CHAR = float(os.environ.get("PRICE_SYNTHESIS_CHAR", "0.000004"))
PRICE_PER_CLONE_REQUEST = float(os.environ.get("PRICE_CLONE_REQ", "0.05"))
PRICE_PER_ENHANCE_MINUTE = float(os.environ.get("PRICE_ENHANCE_MIN", "0.002"))


# =============================================================================
# MODELS
# =============================================================================

class PlanTier(str, Enum):
    FREE = "free"
    PRO = "pro"
    ENTERPRISE = "enterprise"


class UsageType(str, Enum):
    TRANSCRIBE = "transcribe"
    SYNTHESIZE = "synthesize"
    CLONE = "clone"
    ENHANCE = "enhance"
    ANALYZE = "analyze"
    STORAGE = "storage"


class UsageRecord(BaseModel):
    timestamp: str
    user_id: str
    usage_type: UsageType
    quantity: float  # minutes, characters, requests, bytes
    unit: str  # "minutes", "characters", "requests", "bytes"
    cost: float
    metadata: Dict = {}


class Plan(BaseModel):
    tier: PlanTier
    name: str
    price_monthly: float
    limits: Dict[str, int]  # usage_type -> max per month
    features: List[str]
    overage_rates: Dict[str, float] = {}


class UserUsage(BaseModel):
    user_id: str
    plan: PlanTier = PlanTier.FREE
    billing_cycle_start: str
    usage: Dict[str, float] = {}  # usage_type -> total quantity
    cost: float = 0.0
    stripe_customer_id: Optional[str] = None
    stripe_subscription_id: Optional[str] = None


# =============================================================================
# DEFAULT PLANS
# =============================================================================

DEFAULT_PLANS = {
    PlanTier.FREE: Plan(
        tier=PlanTier.FREE,
        name="Free",
        price_monthly=0.0,
        limits={
            "transcribe": 60,  # 60 minutes/month
            "synthesize": 10000,  # 10k characters/month
            "clone": 10,  # 10 clone requests/month
            "enhance": 30,  # 30 minutes/month
            "analyze": 100,  # 100 requests/month
            "storage": 100 * 1024 * 1024  # 100MB storage
        },
        features=["Basic STT", "Basic TTS", "Community support"]
    ),
    PlanTier.PRO: Plan(
        tier=PlanTier.PRO,
        name="Pro",
        price_monthly=29.99,
        limits={
            "transcribe": 600,  # 10 hours/month
            "synthesize": 100000,  # 100k characters/month
            "clone": 100,  # 100 clone requests/month
            "enhance": 300,  # 5 hours/month
            "analyze": 1000,  # 1000 requests/month
            "storage": 1024 * 1024 * 1024  # 1GB storage
        },
        features=[
            "Priority STT", "HD TTS", "Voice cloning",
            "API access", "Email support", "Webhooks"
        ],
        overage_rates={
            "transcribe": PRICE_PER_TRANSCRIBE_MINUTE,
            "synthesize": PRICE_PER_SYNTHESIS_CHAR,
            "clone": PRICE_PER_CLONE_REQUEST,
            "enhance": PRICE_PER_ENHANCE_MINUTE
        }
    ),
    PlanTier.ENTERPRISE: Plan(
        tier=PlanTier.ENTERPRISE,
        name="Enterprise",
        price_monthly=299.99,
        limits={
            "transcribe": 6000,  # 100 hours/month
            "synthesize": 1000000,  # 1M characters/month
            "clone": 1000,  # unlimited effectively
            "enhance": 3000,  # 50 hours/month
            "analyze": 10000,  # 10k requests/month
            "storage": 10 * 1024 * 1024 * 1024  # 10GB storage
        },
        features=[
            "Unlimited STT", "Ultra HD TTS", "Custom voice cloning",
            "Dedicated API", "Priority support", "SLA",
            "Custom integrations", "On-premise option"
        ],
        overage_rates={
            "transcribe": PRICE_PER_TRANSCRIBE_MINUTE * 0.5,
            "synthesize": PRICE_PER_SYNTHESIS_CHAR * 0.5,
            "clone": PRICE_PER_CLONE_REQUEST * 0.5,
            "enhance": PRICE_PER_ENHANCE_MINUTE * 0.5
        }
    )
}


# =============================================================================
# USAGE TRACKER
# =============================================================================

class UsageTracker:
    """Tracks and manages API usage per user."""
    
    def __init__(self, storage_path: Path = USAGE_STORAGE_PATH):
        self.storage_path = storage_path
        self.storage_path.mkdir(parents=True, exist_ok=True)
        self._users: Dict[str, UserUsage] = {}
        self._plans = DEFAULT_PLANS
    
    def _get_user_file(self, user_id: str) -> Path:
        """Get storage file path for user."""
        return self.storage_path / f"{user_id}.json"
    
    def _load_user(self, user_id: str) -> UserUsage:
        """Load user usage data."""
        if user_id in self._users:
            return self._users[user_id]
        
        user_file = self._get_user_file(user_id)
        if user_file.exists():
            try:
                with open(user_file, 'r') as f:
                    data = json.load(f)
                    user = UserUsage(**data)
            except Exception as e:
                print(f"Error loading user {user_id}: {e}")
                user = self._create_user(user_id)
        else:
            user = self._create_user(user_id)
        
        self._users[user_id] = user
        return user
    
    def _create_user(self, user_id: str) -> UserUsage:
        """Create new user usage record."""
        user = UserUsage(
            user_id=user_id,
            billing_cycle_start=datetime.utcnow().replace(day=1).isoformat()
        )
        self._save_user(user)
        return user
    
    def _save_user(self, user: UserUsage):
        """Save user usage data."""
        user_file = self._get_user_file(user.user_id)
        with open(user_file, 'w') as f:
            json.dump(user.model_dump(), f, indent=2)
    
    def _check_billing_cycle(self, user: UserUsage):
        """Reset usage if new billing cycle."""
        cycle_start = datetime.fromisoformat(user.billing_cycle_start)
        now = datetime.utcnow()
        
        # Check if we're in a new month
        if now.year > cycle_start.year or now.month > cycle_start.month:
            user.billing_cycle_start = now.replace(day=1).isoformat()
            user.usage = {}
            user.cost = 0.0
            self._save_user(user)
    
    def record_usage(
        self,
        user_id: str,
        usage_type: UsageType,
        quantity: float,
        unit: str,
        metadata: Dict = None
    ) -> Dict:
        """
        Record API usage for a user.
        Returns usage info and whether limit was exceeded.
        """
        user = self._load_user(user_id)
        self._check_billing_cycle(user)
        
        plan = self._plans.get(user.plan, DEFAULT_PLANS[PlanTier.FREE])
        limit = plan.limits.get(usage_type.value, 0)
        current = user.usage.get(usage_type.value, 0)
        
        # Calculate cost
        cost = 0.0
        overage = 0.0
        
        if current + quantity > limit:
            overage = (current + quantity) - limit
            overage_rate = plan.overage_rates.get(usage_type.value, 0)
            cost = overage * overage_rate
        
        # Update usage
        user.usage[usage_type.value] = current + quantity
        user.cost += cost
        self._save_user(user)
        
        # Save detailed record
        record = UsageRecord(
            timestamp=datetime.utcnow().isoformat(),
            user_id=user_id,
            usage_type=usage_type,
            quantity=quantity,
            unit=unit,
            cost=cost,
            metadata=metadata or {}
        )
        self._save_record(record)
        
        return {
            "usage_type": usage_type.value,
            "quantity": quantity,
            "total_used": user.usage[usage_type.value],
            "limit": limit,
            "remaining": max(0, limit - user.usage[usage_type.value]),
            "overage": overage,
            "cost": cost,
            "within_limit": user.usage[usage_type.value] <= limit
        }
    
    def _save_record(self, record: UsageRecord):
        """Save individual usage record for analytics."""
        date_str = datetime.utcnow().strftime("%Y-%m-%d")
        records_file = self.storage_path / f"records_{date_str}.jsonl"
        
        with open(records_file, 'a') as f:
            f.write(json.dumps(record.model_dump()) + "\n")
    
    def get_usage(self, user_id: str) -> Dict:
        """Get current usage for a user."""
        user = self._load_user(user_id)
        self._check_billing_cycle(user)
        
        plan = self._plans.get(user.plan, DEFAULT_PLANS[PlanTier.FREE])
        
        usage_summary = {}
        for usage_type in UsageType:
            limit = plan.limits.get(usage_type.value, 0)
            used = user.usage.get(usage_type.value, 0)
            usage_summary[usage_type.value] = {
                "used": used,
                "limit": limit,
                "remaining": max(0, limit - used),
                "percentage": round((used / limit * 100) if limit > 0 else 0, 2)
            }
        
        return {
            "user_id": user_id,
            "plan": user.plan,
            "billing_cycle_start": user.billing_cycle_start,
            "total_cost": user.cost,
            "usage": usage_summary
        }
    
    def check_limit(self, user_id: str, usage_type: UsageType, quantity: float = 1) -> Dict:
        """Check if user has remaining quota for an operation."""
        user = self._load_user(user_id)
        self._check_billing_cycle(user)
        
        plan = self._plans.get(user.plan, DEFAULT_PLANS[PlanTier.FREE])
        limit = plan.limits.get(usage_type.value, 0)
        current = user.usage.get(usage_type.value, 0)
        
        # Pro and Enterprise can go over limit (with charges)
        allow_overage = user.plan in [PlanTier.PRO, PlanTier.ENTERPRISE]
        
        return {
            "allowed": (current + quantity <= limit) or allow_overage,
            "within_limit": current + quantity <= limit,
            "current": current,
            "limit": limit,
            "remaining": max(0, limit - current),
            "allow_overage": allow_overage
        }
    
    def set_plan(self, user_id: str, plan: PlanTier):
        """Set user's plan tier."""
        user = self._load_user(user_id)
        user.plan = plan
        self._save_user(user)
    
    def get_plan(self, plan_tier: PlanTier) -> Plan:
        """Get plan details."""
        return self._plans.get(plan_tier, DEFAULT_PLANS[PlanTier.FREE])
    
    def list_plans(self) -> List[Plan]:
        """List all available plans."""
        return list(self._plans.values())


# Global usage tracker
usage_tracker = UsageTracker()


# =============================================================================
# BILLING INTEGRATION
# =============================================================================

class BillingManager:
    """Manages billing integration with Stripe."""
    
    def __init__(self):
        self.enabled = STRIPE_AVAILABLE and bool(os.environ.get("STRIPE_API_KEY"))
    
    def create_customer(self, user_id: str, email: str, name: str = None) -> Optional[str]:
        """Create a Stripe customer."""
        if not self.enabled:
            return None
        
        try:
            customer = stripe.Customer.create(
                email=email,
                name=name,
                metadata={"user_id": user_id}
            )
            
            # Update user with Stripe customer ID
            user = usage_tracker._load_user(user_id)
            user.stripe_customer_id = customer.id
            usage_tracker._save_user(user)
            
            return customer.id
        except Exception as e:
            print(f"Stripe customer creation failed: {e}")
            return None
    
    def create_subscription(self, user_id: str, plan: PlanTier) -> Optional[str]:
        """Create a Stripe subscription."""
        if not self.enabled:
            return None
        
        user = usage_tracker._load_user(user_id)
        if not user.stripe_customer_id:
            return None
        
        # Map plans to Stripe price IDs (configure these in Stripe dashboard)
        price_ids = {
            PlanTier.PRO: os.environ.get("STRIPE_PRO_PRICE_ID"),
            PlanTier.ENTERPRISE: os.environ.get("STRIPE_ENTERPRISE_PRICE_ID")
        }
        
        price_id = price_ids.get(plan)
        if not price_id:
            return None
        
        try:
            subscription = stripe.Subscription.create(
                customer=user.stripe_customer_id,
                items=[{"price": price_id}],
                metadata={"user_id": user_id}
            )
            
            user.stripe_subscription_id = subscription.id
            user.plan = plan
            usage_tracker._save_user(user)
            
            return subscription.id
        except Exception as e:
            print(f"Stripe subscription creation failed: {e}")
            return None
    
    def cancel_subscription(self, user_id: str) -> bool:
        """Cancel a Stripe subscription."""
        if not self.enabled:
            return False
        
        user = usage_tracker._load_user(user_id)
        if not user.stripe_subscription_id:
            return False
        
        try:
            stripe.Subscription.delete(user.stripe_subscription_id)
            user.stripe_subscription_id = None
            user.plan = PlanTier.FREE
            usage_tracker._save_user(user)
            return True
        except Exception as e:
            print(f"Stripe subscription cancellation failed: {e}")
            return False
    
    def record_overage(self, user_id: str, amount: float, description: str) -> Optional[str]:
        """Record overage charges in Stripe."""
        if not self.enabled or amount <= 0:
            return None
        
        user = usage_tracker._load_user(user_id)
        if not user.stripe_customer_id:
            return None
        
        try:
            # Create invoice item for overage
            invoice_item = stripe.InvoiceItem.create(
                customer=user.stripe_customer_id,
                amount=int(amount * 100),  # Stripe uses cents
                currency="usd",
                description=description
            )
            return invoice_item.id
        except Exception as e:
            print(f"Stripe overage recording failed: {e}")
            return None
    
    def create_checkout_session(self, user_id: str, plan: PlanTier, success_url: str, cancel_url: str) -> Optional[str]:
        """Create a Stripe Checkout session for plan upgrade."""
        if not self.enabled:
            return None
        
        price_ids = {
            PlanTier.PRO: os.environ.get("STRIPE_PRO_PRICE_ID"),
            PlanTier.ENTERPRISE: os.environ.get("STRIPE_ENTERPRISE_PRICE_ID")
        }
        
        price_id = price_ids.get(plan)
        if not price_id:
            return None
        
        try:
            session = stripe.checkout.Session.create(
                mode="subscription",
                line_items=[{"price": price_id, "quantity": 1}],
                success_url=success_url,
                cancel_url=cancel_url,
                metadata={"user_id": user_id, "plan": plan.value}
            )
            return session.url
        except Exception as e:
            print(f"Stripe checkout session creation failed: {e}")
            return None


# Global billing manager
billing_manager = BillingManager()


# =============================================================================
# BILLING ROUTER
# =============================================================================

def create_billing_router():
    """Create FastAPI router with billing endpoints."""
    from fastapi import APIRouter, Depends, HTTPException
    from ai.api.auth import require_auth
    
    router = APIRouter(prefix="/billing", tags=["Billing"])
    
    @router.get("/usage")
    async def get_usage(user: Dict = Depends(require_auth)):
        """Get current usage and limits."""
        return usage_tracker.get_usage(user["user_id"])
    
    @router.get("/plans")
    async def list_plans():
        """List available plans."""
        return [p.model_dump() for p in usage_tracker.list_plans()]
    
    @router.get("/plans/{plan_tier}")
    async def get_plan(plan_tier: PlanTier):
        """Get plan details."""
        plan = usage_tracker.get_plan(plan_tier)
        return plan.model_dump()
    
    @router.post("/upgrade")
    async def upgrade_plan(
        plan: PlanTier,
        success_url: str,
        cancel_url: str,
        user: Dict = Depends(require_auth)
    ):
        """Upgrade to a paid plan (returns Stripe checkout URL)."""
        if not billing_manager.enabled:
            raise HTTPException(status_code=503, detail="Billing not configured")
        
        checkout_url = billing_manager.create_checkout_session(
            user["user_id"], plan, success_url, cancel_url
        )
        
        if not checkout_url:
            raise HTTPException(status_code=400, detail="Could not create checkout session")
        
        return {"checkout_url": checkout_url}
    
    @router.post("/cancel")
    async def cancel_subscription(user: Dict = Depends(require_auth)):
        """Cancel current subscription."""
        if not billing_manager.enabled:
            raise HTTPException(status_code=503, detail="Billing not configured")
        
        if billing_manager.cancel_subscription(user["user_id"]):
            return {"status": "cancelled", "plan": "free"}
        else:
            raise HTTPException(status_code=400, detail="No active subscription")
    
    @router.post("/webhook")
    async def stripe_webhook(request):
        """Handle Stripe webhooks."""
        if not billing_manager.enabled:
            raise HTTPException(status_code=503, detail="Billing not configured")
        
        # TODO: Implement webhook signature verification and handling
        # This would handle subscription updates, payment failures, etc.
        return {"received": True}
    
    return router
