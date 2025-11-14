from config import Config

print("Testing configuration:")
print(f"SECRET_KEY: {Config.SECRET_KEY}")
print(f"FIREBASE_CREDENTIALS_PATH: {Config.FIREBASE_CREDENTIALS_PATH}")
print(f"DEBUG: {Config.DEBUG}")
print(f"PORT: {Config.PORT}")
