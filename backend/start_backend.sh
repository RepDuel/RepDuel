#!/bin/bash

echo "--- Starting RepDuel Backend ---"

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Activate the virtual environment from the root project folder
if [ -f "$PROJECT_ROOT/.venv/bin/activate" ]; then
    source "$PROJECT_ROOT/.venv/bin/activate"
else
    echo "Virtual environment not found at $PROJECT_ROOT/.venv. Please create it first."
    exit 1
fi

# Change directory to backend
cd "$SCRIPT_DIR"

# Start the FastAPI server
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000 --log-level error

