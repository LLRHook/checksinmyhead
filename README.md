# ChecksInMyHead Setup

## Project Structure
```
repo-root/
│
├── backend/
│ ├── main.py # FastAPI entrypoint
│ ├── models/ # MongoDB schemas
│ ├── routes/ # FastAPI routers
│ ├── utils/ # Helper functions (OCR, parsing, etc.)
│ ├── .env.example # Template env file
│ └── pyproject.toml # Ruff config
│
├── frontend/ # Flutter code goes here
├── docs/ # Any diagrams, architecture notes
├── sample-data/receipts/ # Real/test receipts
├── tests/ # Pytest or unit tests
├── .pre-commit-config.yaml
└── README.md
```

## Setup Instructions

### 1. Install uv
```bash
# Install uv directly (not through pip)
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 2. Set up Environment Variables
Copy the example env file and fill in your values:
```bash
# On Windows
cp backend\.env.example backend\.env

# On Unix/Linux/macOS
cp backend/.env.example backend/.env
```

### 3. Set up Virtual Environment and Install Dependencies
```bash
# Create a virtual environment
uv venv

# Activate the virtual environment
# On Windows
.venv\Scripts\activate
# On Unix/Linux/macOS
source .venv/bin/activate

# Install dependencies
uv pip install -r requirements.txt
```

### 4. Set up Pre-commit
```bash
pre-commit install
```

### 5. Run the Server
```bash
uvicorn backend.main:app --reload
```

Test the API:
- Open your browser and visit: http://localhost:8000/ping
- You should see: `{"message": "pong"}`