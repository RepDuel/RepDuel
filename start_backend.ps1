Write-Host "--- Starting GymRank Backend ---"

# Change to backend directory
if (!(Test-Path -Path "./backend")) {
    Write-Host "Backend folder not found!"
    exit 1
}
Set-Location ./backend

# Activate virtual environment (Windows path)
if (Test-Path ".venv\Scripts\Activate.ps1") {
    & ".venv\Scripts\Activate.ps1"
} else {
    Write-Host "Virtual environment not found. Please create it first."
    exit 1
}

# Run Uvicorn server
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
