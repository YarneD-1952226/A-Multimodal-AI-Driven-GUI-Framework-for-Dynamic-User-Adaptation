#!/usr/bin/env bash
set -euo pipefail

echo "Starting environment + MongoDB + FastAPI backend..."

# Resolve script directory and move there
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Python / venv setup
if ! command -v python3 >/dev/null 2>&1; then
    echo "✗ python3 not found in PATH"
    exit 1
fi

if [ ! -d ".venv" ]; then
    echo "Creating virtual environment (.venv)..."
    python3 -m venv .venv
else
    echo "✓ Virtual environment (.venv) already exists"
fi

# Activate venv
# shellcheck disable=SC1091
source .venv/bin/activate

# Upgrade pip
python -m pip install --upgrade pip >/dev/null

# Install requirements if present
if [ -f "requirements.txt" ]; then
    echo "Installing dependencies from requirements.txt..."
    pip install -r requirements.txt
else
    echo "No requirements.txt found (skipping dependency install)"
fi

# Verify uvicorn present
if ! command -v uvicorn >/dev/null 2>&1; then
    echo "✗ uvicorn is not installed (add it to requirements.txt)"
    exit 1
fi

# Start MongoDB if not running
echo "Checking MongoDB..."
if pgrep -x "mongod" > /dev/null; then
        echo "✓ MongoDB is already running"
else
        echo "Starting MongoDB..."
        if ! command -v mongod >/dev/null 2>&1; then
                echo "✗ mongod not found in PATH"
                exit 1
        fi
        mongod --fork
        sleep 3
        if pgrep -x "mongod" > /dev/null; then
                echo "✓ MongoDB started successfully"
        else
                echo "✗ Failed to start MongoDB"
                exit 1
        fi
fi

# Start FastAPI backend (runs in foreground)
echo "Starting FastAPI backend (uvicorn)..."
# If backend.py is in this directory and defines 'app'
uvicorn backend:app --host 0.0.0.0 --port 8000 --reload