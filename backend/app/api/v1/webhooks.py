# backend/app/api/v1/endpoints/webhooks.py

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_db
from app.core.config import settings
from app.schemas import user as schemas
from app.services.user_service import get_user_by_id, update_user

router = APIRouter(prefix="/webhooks", tags=["webhooks"])

# List of RevenueCat event types that grant entitlements
ENTITLEMENT_GRANTING_EVENTS = [
    "INITIAL_PURCHASE",
    "RENEWAL",
    "PRODUCT_CHANGE",
    "UNCANCELLATION",
]

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
    # 1. Verify the Authorization header
    expected_token = f"Bearer {settings.REVENUECAT_WEBHOOK_AUTH_TOKEN}"
    if authorization != expected_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Unauthorized"
        )

    # 2. Parse the incoming event data
    try:
        data = await request.json()
        event = data.get("event", {})
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid JSON payload"
        )

    event_type = event.get("type")
    user_id = event.get("app_user_id")

    if not user_id:
        # Can't process an event without a user ID
        return {"status": "success", "detail": "Event ignored, no user ID."}

    # 3. Find the user in our database
    user = await get_user_by_id(db, user_id)
    if not user:
        # If we can't find the user, we can't update them.
        # Still return a 200 so RevenueCat doesn't keep retrying.
        return {"status": "success", "detail": f"User {user_id} not found."}

    # 4. Determine the new subscription tier based on entitlements
    active_entitlements = set(event.get("entitlements", []))
    new_tier = "free"
    if "platinum" in active_entitlements:
        new_tier = "platinum"
    elif "gold" in active_entitlements:
        new_tier = "gold"
        
    # Also handle expiration events
    if event_type == "EXPIRATION":
        new_tier = "free"

    # 5. Update the user only if the tier has changed
    if user.subscription_level != new_tier:
        print(f"Updating user {user.id} subscription from {user.subscription_level} to {new_tier}")
        await update_user(db, user, schemas.UserUpdate(subscription_level=new_tier))
    else:
        print(f"User {user.id} subscription already up-to-date: {new_tier}")


    return {"status": "success"}