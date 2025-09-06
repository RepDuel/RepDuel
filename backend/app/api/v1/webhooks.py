# backend/app/api/v1/endpoints/webhooks.py

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_db
from app.core.config import settings
from app.schemas import user as schemas
from app.services.user_service import get_user_by_id, update_user

router = APIRouter(prefix="/webhooks", tags=["webhooks"])

# A clear mapping of store Product IDs to your app's internal tier names
PRODUCT_ID_TO_TIER = {
    "io.repduel.app.gold.monthly": "gold",
    "io.repduel.app.platinum.monthly": "platinum"
    # Add other product IDs here as you create them
}

@router.post(
    "/revenuecat",
    status_code=status.HTTP_200_OK,
    summary="Handle RevenueCat Webhooks",
)
async def revenuecat_webhook(
    request: Request,
    authorization: str | None = Header(None),
    db: AsyncSession = Depends(get_db),
):
    """
    Handles incoming webhooks from RevenueCat to update user subscription status.
    """
    expected_token = settings.REVENUECAT_WEBHOOK_AUTH_TOKEN
    if authorization != expected_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Unauthorized"
        )

    try:
        data = await request.json()
        event = data.get("event", {})
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid JSON payload"
        )

    # For debugging, let's see the whole event payload in the logs
    print(f"--- Received RevenueCat Event --- \n{event}\n--------------------")

    user_id = event.get("app_user_id")
    if not user_id:
        return {"status": "success", "detail": "Event ignored, no user ID."}

    user = await get_user_by_id(db, user_id)
    if not user:
        return {"status": "success", "detail": f"User {user_id} not found."}

    # ========== THIS IS THE ROBUST FIX ==========
    new_tier = "free"
    event_type = event.get("type")
    
    if event_type == "EXPIRATION" or event_type == "CANCELLATION":
        new_tier = "free"
    else:
        # First, try to get the tier from the entitlements list (best case).
        active_entitlements = set(event.get("entitlements", []))
        if "platinum" in active_entitlements:
            new_tier = "platinum"
        elif "gold" in active_entitlements:
            new_tier = "gold"
        
        # SECOND, if entitlements are empty, fall back to checking the product_id.
        if new_tier == "free" and "product_id" in event:
            product_id = event.get("product_id")
            if product_id in PRODUCT_ID_TO_TIER:
                new_tier = PRODUCT_ID_TO_TIER[product_id]
    # ==========================================

    if user.subscription_level != new_tier:
        print(f"UPDATING user {user.id} from '{user.subscription_level}' to '{new_tier}'")
        await update_user(db, user, schemas.UserUpdate(subscription_level=new_tier))
    else:
        print(f"User {user.id} subscription is already up-to-date: '{new_tier}'")

    return {"status": "success"}