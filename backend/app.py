import uvicorn
import os
from dotenv import load_dotenv
from fastapi_app import app

load_dotenv()

if __name__ == "__main__":
    # Get configuration from environment variables
    host = os.environ.get('HOST', '0.0.0.0')  # Listen on all interfaces by default
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('DEBUG', 'True').lower() == 'true'
    
    # Run on 0.0.0.0 to accept connections from any interface (localhost, network, etc.)
    # This allows the Flutter app to connect from emulator, simulator, or physical device
    uvicorn.run(
        "fastapi_app:app",
        host=host,
        port=port,
        reload=debug,  # Enable auto-reloading only in debug mode
        log_level="info",
        access_log=True,  # Enable access logs to see incoming requests
    )
