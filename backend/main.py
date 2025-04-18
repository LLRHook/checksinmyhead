from fastapi import FastAPI
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()


@app.get("/")
async def root():
    return {"message": "Welcome to ChecksInMyHead API"}


@app.get("/ping")
def ping():
    return {"message": "pong"}
