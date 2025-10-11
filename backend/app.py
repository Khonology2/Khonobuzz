import uvicorn
from fastapi_app import app

if __name__ == "__main__":
    uvicorn.run(
        "fastapi_app:app",
        host="0.0.0.0",
        port=5000,
        reload=True,  # Enable auto-reloading for development
        log_level="info"
    )
