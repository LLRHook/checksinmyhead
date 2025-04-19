# MongoDB Connection Guide

This guide explains how to connect to our MongoDB database for both development and production environments.

## Prerequisites

- MongoDB Compass installed on your machine
- Access to the MongoDB Atlas account
- Python 3.8+ with FastAPI and pymongo installed

## Environment Setup

1. Create a `.env` file in the `backend/` directory based on the `.env.example` template
2. Add your MongoDB connection string:

```
MONGODB_URI=mongodb+srv://checksinhead:<db_password>@prod.wswqkdz.mongodb.net/
MONGODB_DATABASE=your_database_name
```

Replace `<db_password>` with the actual password for the `checksinhead` user.

## Connecting with MongoDB Compass

1. Open MongoDB Compass
2. In the connection string field, paste:
   ```
   mongodb+srv://checksinhead:<db_password>@prod.wswqkdz.mongodb.net/
   ```
3. Replace `<db_password>` with the actual password
4. Click "Connect"

### Troubleshooting Compass Connection

If you cannot connect:

- Verify your IP address is whitelisted in MongoDB Atlas
  - Go to Atlas → Network Access → Add your current IP
- Check that you're using the correct password
- Ensure you're not behind a restrictive firewall

## FastAPI Database Integration

Our application uses FastAPI's dependency injection for MongoDB connection management.

### How It Works

1. The database connection is initialized in `backend/database/mongodb.py`
2. Endpoints can access collections through dependency injection
3. Connection pooling is handled automatically by pymongo

### Example Usage

```python
# In your route file
from fastapi import Depends
from database.mongodb import get_collection

@app.post("/receipts/")
async def create_receipt(
    receipt_data: ReceiptModel,
    collection = Depends(lambda: get_collection("receipts"))
):
    result = collection.insert_one(receipt_data.dict())
    return {"id": str(result.inserted_id)}
```

## Database Schema

The primary collections in our database are:

- `receipts`: Stores processed receipt information
- `users`: User account information
- `items`: Extracted line items from receipts

## Common Operations

### Finding Documents

```python
# Get all receipts for a specific user
receipts = collection.find({"user_id": user_id})
```

### Inserting Documents

```python
# Insert a new receipt
result = collection.insert_one({
    "merchant": "Grocery Store",
    "total": 45.67,
    "date": "2025-04-19",
    "user_id": "user123"
})
```

### Updating Documents

```python
# Update a receipt
result = collection.update_one(
    {"_id": receipt_id},
    {"$set": {"total": 50.00}}
)
```

## Additional Resources

- [MongoDB Python Driver Documentation](https://pymongo.readthedocs.io/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [MongoDB Atlas Documentation](https://docs.atlas.mongodb.com/)