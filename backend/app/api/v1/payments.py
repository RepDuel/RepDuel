# backend/app/api/v1/payments.py

import stripe
from fastapi import (APIRouter, Depends,  # Added Request, Response
                     HTTPException, Request, Response, status)
from sqlalchemy import select  # Added select
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
        checkout_session = stripe.checkout.Session.create(
            customer=stripe_customer_id,
            payment_method_types=["card"],
            line_items=[
                {"price": checkout_data.price_id, "quantity": 1},
            ],
            mode="subscription",
            success_url=checkout_data.success_url,
            cancel_url=checkout_data.cancel_url,
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
        return_url = "https://yourapp.com/profile"
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


# --- START: NEW WEBHOOK ENDPOINT ---


@router.post("/webhook", status_code=status.HTTP_200_OK, include_in_schema=False)
async def stripe_webhook(request: Request, db: AsyncSession = Depends(get_db)):
    """
    Listens for events from Stripe's servers.

    This is the most important endpoint for fulfillment. It is responsible for:
    1. Verifying the incoming request is genuinely from Stripe.
    2. Handling the 'checkout.session.completed' event.
    3. Updating the user's subscription status in the database.
    """
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")

    # Step 1: Verify the event's signature to ensure it's from Stripe.
    try:
        event = stripe.Webhook.construct_event(
            payload=payload,
            sig_header=sig_header,
            secret=settings.STRIPE_WEBHOOK_SECRET,
        )
    except ValueError as e:
        # Invalid payload
        raise HTTPException(status_code=400, detail=f"Invalid webhook payload: {e}")
    except stripe.error.SignatureVerificationError as e:
        # Invalid signature
        raise HTTPException(status_code=400, detail=f"Invalid webhook signature: {e}")

    # Step 2: Handle the 'checkout.session.completed' event.
    if event["type"] == "checkout.session.completed":
        session = event["data"]["object"]
        stripe_customer_id = session.get("customer")
        stripe_subscription_id = session.get("subscription")

        if not stripe_customer_id:
            print("Webhook error: 'customer' not found in session object.")
            return Response(status_code=status.HTTP_400_BAD_REQUEST)

        print(
            f"Webhook received: checkout.session.completed for customer {stripe_customer_id}"
        )

        # Step 3: Find the user and update their subscription in our database.
        result = await db.execute(
            select(User).where(User.stripe_customer_id == stripe_customer_id)
        )
        user = result.scalar_one_or_none()

        if user:
            user.subscription_level = (
                "gold"  # You can add more logic here for different plans
            )
            user.stripe_subscription_id = stripe_subscription_id
            db.add(user)
            await db.commit()
            print(f"Database updated: User {user.email} is now on the 'gold' plan.")
        else:
            print(
                f"Webhook error: User with Stripe customer ID {stripe_customer_id} not found."
            )

    else:
        print(f"Unhandled event type received: {event['type']}")

    # Step 4: Acknowledge the event to Stripe.
    return Response(status_code=status.HTTP_200_OK)
