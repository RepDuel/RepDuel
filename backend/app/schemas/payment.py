# backend/app/schemas/payment.py

from pydantic import BaseModel, Field

# --- Schemas for Stripe Checkout ---


class StripeCheckoutSessionCreate(BaseModel):
    """
    Schema for the request body sent from the frontend when a user wants to subscribe.
    """

    price_id: str = Field(
        ...,
        description="The ID of the Stripe Price object (e.g., 'price_...').",
        examples=["price_1P6sL3A4B5C6D7E8f9g0h1i2"],
    )
    success_url: str = Field(
        ...,
        description="The URL to redirect the user to after a successful payment.",
        examples=["https://yourapp.com/payment/success"],
    )
    cancel_url: str = Field(
        ...,
        description="The URL to redirect the user to if they cancel the payment.",
        examples=["https://yourapp.com/payment/cancel"],
    )


class StripeCheckoutSessionResponse(BaseModel):
    """
    Schema for the response sent back to the frontend, containing the URL
    for the Stripe-hosted checkout page.
    """

    checkout_url: str


# --- Schemas for Apple IAP Verification ---


class AppleReceiptVerificationRequest(BaseModel):
    """
    Schema for the request from the frontend to verify an Apple receipt.
    This will likely be sent from a service like RevenueCat to your server via webhook.
    """

    receipt_data: str = Field(
        ..., description="The base64-encoded receipt data from the Apple purchase."
    )
    # You might add other fields here depending on what data you send
    # from your app or receive from RevenueCat webhooks.


class AppleReceiptVerificationResponse(BaseModel):
    """
    Schema for the response confirming the Apple IAP verification.
    """

    status: str = Field(
        ...,
        description="The status of the verification.",
        examples=["success", "error"],
    )
    subscription_level: str = Field(
        ...,
        description="The user's new subscription level after verification.",
        examples=["free", "gold", "platinum"],
    )


# --- Schemas for General Portal Session (Stripe Customer Portal) ---


class StripePortalSessionResponse(BaseModel):
    """
    Schema for the response containing the URL to the Stripe Customer Portal,
    where users can manage their subscriptions.
    """

    portal_url: str
