# backend/app/main.py

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.v1.api_router import api_router

app = FastAPI()

# Define the origins that should be allowed to make cross-origin requests
origins = [
    "http://localhost:3000",  # adjust this to your frontend URL if different
    "http://localhost:8000",  # if your frontend runs here or backend self calls
    "http://localhost:your_flutter_port",  # add if Flutter web uses another port
    "*",  # optionally allow all origins, but be careful with this in production
]

# Add CORS middleware to handle preflight OPTIONS requests and allow cross-origin calls
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,           # origins allowed to access your backend
    allow_credentials=True,          # allow cookies, auth headers, etc.
    allow_methods=["*"],             # allow all HTTP methods, including OPTIONS
    allow_headers=["*"],             # allow all headers
)

app.include_router(api_router)
