# backend/app/schemas/payment.py

from pydantic import BaseModel, Field


class StripeCheckoutSessionCreate(BaseModel):
    price_id: str = Field(..., description="The ID of the Stripe Price object.")
    success_url: str = Field(..., description="The URL after a successful payment.")
    cancel_url: str = Field(..., description="The URL if the payment is canceled.")


class StripeCheckoutSessionResponse(BaseModel):
    checkout_url: str


class AppleReceiptVerificationRequest(BaseModel):
    receipt_data: str = Field(..., description="The base64-encoded receipt data.")


class AppleReceiptVerificationResponse(BaseModel):
    status: str = Field(..., description="The status of the verification.")
    subscription_level: str = Field(..., description="The user's new subscription level.")


class StripePortalSessionResponse(BaseModel):
    portal_url: str
