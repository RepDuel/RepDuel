# backend/app/api/v1/endpoints/webhooks.py

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from time import time

from app.api.v1.deps import get_db
from app.core.config import settings
from app.schemas import user as schemas
from app.services.user_service import get_user_by_id, update_user
from app.models.user import User  # <-- make sure this import is available

router = APIRouter(prefix="/webhooks", tags=["webhooks"])

PRODUCT_ID_TO_TIER = {
    "io.repduel.app.gold.monthly": "gold",
    "io.repduel.app.platinum.monthly": "platinum",
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
    if authorization != settings.REVENUECAT_WEBHOOK_AUTH_TOKEN:
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

    print(f"--- Received RevenueCat Event --- \n{event}\n--------------------")

    user_id = event.get("app_user_id")
    if not user_id:
        return {"status": "success", "detail": "Event ignored, no user ID."}

    user = await get_user_by_id(db, user_id)
    if not user:
        return {"status": "success", "detail": f"User {user_id} not found."}

    event_type = event.get("type")
    expiration_at_ms = event.get("expiration_at_ms")
    product_id = event.get("product_id")
    entitlement_ids = [e.lower() for e in (event.get("entitlement_ids") or [])]
    now_ms = int(time() * 1000)

    # NEW: get unique Apple transaction id
    original_tx_id = event.get("original_transaction_id")

    # Guard: if another user already owns this original transaction, do not reassign
    if original_tx_id:
        result = await db.execute(
            select(User).where(User.original_transaction_id == original_tx_id)
        )
        existing_owner = result.scalar_one_or_none()
        if existing_owner and existing_owner.id != user.id:
            print(
                f"IGNORING RevenueCat event: transaction {original_tx_id} "
                f"already owned by user {existing_owner.id}, skipping user {user.id}"
            )
            return {"status": "ignored", "detail": "Subscription already owned by another user"}

        # If this user has no transaction stored yet, claim it
        if not user.original_transaction_id:
            user.original_transaction_id = original_tx_id
            db.add(user)
            await db.commit()
            await db.refresh(user)

    def resolve_active_tier() -> str | None:
        if "platinum" in entitlement_ids:
            return "platinum"
        if "gold" in entitlement_ids:
            return "gold"
        if product_id in PRODUCT_ID_TO_TIER:
            return PRODUCT_ID_TO_TIER[product_id]
        return None

    if event_type == "EXPIRATION":
        if isinstance(expiration_at_ms, (int, float)) and expiration_at_ms > now_ms:
            new_tier = resolve_active_tier() or user.subscription_level
        else:
            new_tier = "free"
    elif event_type in ("CANCELLATION", "BILLING_ISSUE"):
        new_tier = resolve_active_tier() or user.subscription_level
    else:
        new_tier = resolve_active_tier() or "free"

    if user.subscription_level != new_tier:
        print(
            f"UPDATING user {user.id} from '{user.subscription_level}' to '{new_tier}'"
        )
        await update_user(db, user, schemas.UserUpdate(subscription_level=new_tier))
    else:
        print(
            f"User {user.id} subscription is already up-to-date: '{new_tier}'"
        )

    return {"status": "success"}
