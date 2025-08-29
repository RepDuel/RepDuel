# backend/app/api/v1/payments.py

import stripe
from fastapi import (APIRouter, Depends,
                     HTTPException, Request, Response, status)
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_db
from app.core.auth import get_current_user
from app.core.config import settings
from app.models.user import User
from app.schemas.payment import (StripeCheckoutSessionCreate,
                                 StripeCheckoutSessionResponse,
                                 StripePortalSessionResponse)

# --- Router Setup ---
router = APIRouter(prefix="/payments", tags=["Payments"])

# --- Stripe API Key Configuration ---
stripe.api_key = settings.STRIPE_SECRET_KEY

# --- API Endpoints ---

@router.post(
    "/create-checkout-session",
    response_model=StripeCheckoutSessionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_checkout_session(
    checkout_data: StripeCheckoutSessionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Creates a Stripe Checkout Session for a user to subscribe to a plan.
    """
    stripe_customer_id = current_user.stripe_customer_id

    if not stripe_customer_id:
        try:
            customer = stripe.Customer.create(
                email=current_user.email,
                name=current_user.username,
                metadata={"app_user_id": str(current_user.id)},
            )
            stripe_customer_id = customer.id
            current_user.stripe_customer_id = stripe_customer_id
            db.add(current_user)
            await db.commit()
            await db.refresh(current_user)
        except stripe.error.StripeError as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to create Stripe customer: {e}",
            )

    try:
        # Reverting to the original, correct parameters for a standard
        # hosted checkout session. The invalid 'after_completion' has been removed.
        checkout_session = stripe.checkout.Session.create(
            customer=stripe_customer_id,
            payment_method_types=["card"],
            line_items=[
                {"price": checkout_data.price_id, "quantity": 1},
            ],
            mode="subscription",
            success_url=checkout_data.success_url,
            cancel_url=checkout_data.cancel_url,
            allow_promotion_codes=True,
            customer_update={"name": "auto", "address": "auto"},
        )

        if not checkout_session.url:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Could not create Stripe checkout session URL.",
            )
        return StripeCheckoutSessionResponse(checkout_url=checkout_session.url)
    except stripe.error.StripeError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create Stripe checkout session: {e}",
        )


@router.post(
    "/create-portal-session",
    response_model=StripePortalSessionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_portal_session(
    current_user: User = Depends(get_current_user),
):
    """
    Creates a Stripe Customer Portal session for a user to manage their subscription.
    """
    if not current_user.stripe_customer_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User is not a Stripe customer.",
        )
    try:
        return_url = settings.APP_URL + "/profile"
        
        portal_session = stripe.billing_portal.Session.create(
            customer=current_user.stripe_customer_id,
            return_url=return_url,
        )
        return StripePortalSessionResponse(portal_url=portal_session.url)
    except stripe.error.StripeError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create Stripe portal session: {e}",
        )


@router.post("/webhook", status_code=status.HTTP_200_OK, include_in_schema=False)
async def stripe_webhook(request: Request, db: AsyncSession = Depends(get_db)):
    """
    Listens for and handles events from Stripe's servers, such as successful payments.
    """
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")

    try:
        event = stripe.Webhook.construct_event(
            payload=payload,
            sig_header=sig_header,
            secret=settings.STRIPE_WEBHOOK_SECRET,
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"Invalid webhook payload: {e}")
    except stripe.error.SignatureVerificationError as e:
        raise HTTPException(status_code=400, detail=f"Invalid webhook signature: {e}")

    # Handle the checkout.session.completed event
    if event["type"] == "checkout.session.completed":
        session = event["data"]["object"]
        stripe_customer_id = session.get("customer")
        stripe_subscription_id = session.get("subscription")

        if not stripe_customer_id:
            print(f"Webhook error: 'customer' not found in session object: {session.get('id')}")
            return Response(status_code=status.HTTP_400_BAD_REQUEST)

        print(f"Webhook received: checkout.session.completed for customer {stripe_customer_id}")

        result = await db.execute(
            select(User).where(User.stripe_customer_id == stripe_customer_id)
        )
        user = result.scalar_one_or_none()

        if user:
            user.subscription_level = "gold" 
            user.stripe_subscription_id = stripe_subscription_id
            db.add(user)
            await db.commit()
            print(f"Database updated: User {user.email} is now on the 'gold' plan.")
        else:
            print(f"Webhook error: User with Stripe customer ID {stripe_customer_id} not found.")

    # Handle other event types like subscription updates or cancellations
    elif event["type"] == "customer.subscription.deleted":
        session = event["data"]["object"]
        stripe_customer_id = session.get("customer")
        print(f"Webhook received: subscription deleted for customer {stripe_customer_id}")
        
    else:
        print(f"Unhandled event type received: {event['type']}")

    return Response(status_code=status.HTTP_200_OK)