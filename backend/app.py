import uvicorn
import os
from dotenv import load_dotenv
from fastapi_app import app
load_dotenv()
if __name__ == "__main__":
    host = os.environ.get('HOST', '0.0.0.0')
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('DEBUG', 'True').lower() == 'true'
    print("=" * 70)
    print("Starting Khonology Backend API")
    print("=" * 70)
    print(f"Host: {host}")
    print(f"Port: {port}")
    print(f"Debug Mode: {debug}")
    print(f"Accessible at: http://localhost:{port}")
    print(f"API Documentation: http://localhost:{port}/docs")
    print("=" * 70)
    uvicorn.run(
        "fastapi_app:app",
        host=host,
        port=port,
        reload=debug,
        log_level="info",
        access_log=True,
    )
