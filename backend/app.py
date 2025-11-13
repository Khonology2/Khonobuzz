import uvicorn
from fastapi_app import app

if __name__ == "__main__":
    # Run on 0.0.0.0 to accept connections from any interface (localhost, network, etc.)
    # This allows the Flutter app to connect from emulator, simulator, or physical device
    uvicorn.run(
        "fastapi_app:app",
        host="0.0.0.0",  # Listen on all interfaces
        port=5000,
        reload=True,  # Enable auto-reloading for development
        log_level="info",
        access_log=True,  # Enable access logs to see incoming requests
    )
