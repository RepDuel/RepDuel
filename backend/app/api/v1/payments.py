# backend/app/api/v1/payments.py

import stripe
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_db
from app.core.auth import get_current_user
from app.core.config import settings
from app.models.user import User
from app.schemas.payment import (
    StripeCheckoutSessionCreate,
    StripeCheckoutSessionResponse,
    StripePortalSessionResponse,
)

# --- Router Setup ---
router = APIRouter(prefix="/payments", tags=["Payments"])


# --- Stripe API Key Configuration ---
# This is a best practice. The API key is set once when the module is loaded.
# It reads the secret key from your application settings.
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

    - Checks if the user is already a Stripe customer. If not, creates one.
    - Creates a checkout session linked to that customer and the selected price.
    - Returns the URL for the Stripe-hosted checkout page.
    """
    stripe_customer_id = current_user.stripe_customer_id

    # Step 1: Ensure the user is a customer in Stripe.
    if not stripe_customer_id:
        try:
            # Create a new customer in Stripe
            customer = stripe.Customer.create(
                email=current_user.email,
                name=current_user.username,  # Or display_name
                metadata={"app_user_id": str(current_user.id)},
            )
            stripe_customer_id = customer.id

            # Save the new Stripe Customer ID to our database
            current_user.stripe_customer_id = stripe_customer_id
            db.add(current_user)
            await db.commit()
            await db.refresh(current_user)

        except stripe.error.StripeError as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to create Stripe customer: {e}",
            )

    # Step 2: Create the Stripe Checkout Session.
    try:
        checkout_session = stripe.checkout.Session.create(
            customer=stripe_customer_id,
            payment_method_types=["card"],
            line_items=[
                {"price": checkout_data.price_id, "quantity": 1},
            ],
            mode="subscription",  # This is crucial for subscriptions
            success_url=checkout_data.success_url,
            cancel_url=checkout_data.cancel_url,
            # To pre-fill the email address on the checkout page
            customer_update={"name": "auto", "address": "auto"},
        )
        
        # The URL is the key piece of information for the frontend.
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
        # TODO: Get the return URL from your app's configuration
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