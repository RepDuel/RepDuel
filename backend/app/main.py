from app.api.v1.api_router import api_router
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Create the FastAPI application
app = FastAPI(
    title="GymRank API", version="1.0.0", description="Backend for the GymRank app"
)

# During development, allow all origins (Flutter web runs on localhost)
# In production, replace ["*"] with specific allowed domains for security
origins = ["*"]  # e.g., ["http://localhost:8080", "http://127.0.0.1:8080"]

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,  # Allow frontend domain
    allow_credentials=True,
    allow_methods=["*"],  # Allow all HTTP methods
    allow_headers=["*"],  # Allow all headers
)

# Include the versioned API router
app.include_router(api_router, prefix="/api/v1")
