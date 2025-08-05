#!/bin/bash
echo "--- Starting RepDuel Backend ---"

# Change to backend directory
cd backend || { echo "Backend folder not found!"; exit 1; }

# Activate virtual environment
if [ -f ".venv/bin/activate" ]; then
  source .venv/bin/activate
else
  echo "Virtual environment not found. Please create it first."
  exit 1
fi

# Run Uvicorn server
exec python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
