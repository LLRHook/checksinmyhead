# ChecksInMyHead Setup

## Project Structure
```
repo-root/
│
├── backend/
│   ├── main.py                # FastAPI entrypoint
│   ├── models/                # MongoDB schemas
│   ├── routes/                # FastAPI routers
│   ├── utils/                 # Helper functions (OCR, parsing, etc.)
│   ├── .env.example           # Template env file
│   └── pyproject.toml         # Ruff config
│
├── frontend/                  # Flutter code goes here
├── docs/                      # Any diagrams, architecture notes
├── sample-data/receipts/     # Real/test receipts
├── tests/                    # Pytest or unit tests
├── .pre-commit-config.yaml
└── README.md
```

## Setup Instructions

### 1. Install uv
```powershell
pip install uv
```

### 2. Set up Environment Variables
Copy the example env file and fill in your values:
```powershell
Copy-Item backend\.env.example backend\.env
```

### 3. Install Dependencies
```powershell
uv pip install fastapi uvicorn python-dotenv pre-commit black
```

### 4. Set up Pre-commit
```powershell
pre-commit install
```

### 5. Run the Server
```powershell
cd backend
uvicorn main:app --reload
```

Test the API:
- Open your browser and visit: http://localhost:8000/ping
- You should see: `{"message": "pong"}` 