# backend/database/mongodb.py
from pymongo import MongoClient
from fastapi import Depends
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# MongoDB connection settings
MONGODB_URI = os.getenv("MONGODB_URI")
DB_NAME = os.getenv("MONGODB_DATABASE", "your_database_name")

# Create MongoDB client
client = MongoClient(MONGODB_URI)

def get_database():
    """Returns database connection"""
    try:
        # Test connection
        client.admin.command('ping')
        return client[DB_NAME]
    except Exception as e:
        print(f"Error connecting to MongoDB: {e}")
        raise e

def get_collection(collection_name: str, db=Depends(get_database)):
    """Returns a collection from the database"""
    return db[collection_name]