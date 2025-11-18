# PDH Token-Based Auto-Login Implementation Guide

## Overview

The Khonobuzz app sends encrypted JWT tokens to PDH via URL query parameters. This guide explains how to implement token validation and auto-login in the PDH app.

## Token Format

The token sent to PDH is:
1. **JWT Token** (contains user info)
2. **Encrypted** with Fernet symmetric encryption
3. **Base64 encoded**

### JWT Payload Structure (Optimized - Shortened Field Names):
```json
{
  "uid": "firebase_user_id",           // Shortened from 'user_id'
  "e": "user@example.com",             // Shortened from 'email'
  "r": "PDH - Employee",                // Shortened from 'module_role'
  "exp": 1234567890                    // Unix timestamp (integer)
  // Note: 'iat' (issued at) is removed to reduce token size
}
```

**Backward Compatibility:** The token verification function expands these back to full names:
- `uid` → `user_id`
- `e` → `email`
- `r` → `module_role`

## Required Environment Variables

Add these to your PDH app's `.env` file:

```env
# JWT Configuration (MUST match Khonobuzz backend)
JWT_SECRET_KEY=HQZsb5lAThMYaDU_9YEAQcFtkIRCbyXSHXS7_ac9O0g

# Encryption Configuration (MUST match Khonobuzz backend)
ENCRYPTION_KEY=6KZRT0MgboM5dmkwTLmHlh81o1P1huopTO3OspUz7LI=

# JWT Expiration (optional, defaults to 24 hours)
JWT_EXPIRATION_HOURS=24
```

**⚠️ CRITICAL:** These keys MUST be identical to the Khonobuzz backend keys for tokens to work.

## Implementation Steps

### Step 1: Install Required Dependencies

```bash
npm install jsonwebtoken cryptography
# or
pip install PyJWT cryptography python-dotenv
```

### Step 2: Create Token Utility Functions

Create a file `token_utils.js` (for Node.js) or `token_utils.py` (for Python):

#### JavaScript/Node.js Version:

```javascript
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { Fernet } = require('cryptography');

// Load from environment variables
const JWT_SECRET_KEY = process.env.JWT_SECRET_KEY;
const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY;
const JWT_ALGORITHM = 'HS256';

/**
 * Decrypt an encrypted token using Fernet
 */
function decryptToken(encryptedToken) {
  if (!ENCRYPTION_KEY) {
    // If no encryption key, assume token is already decrypted
    console.warn('[WARNING] ENCRYPTION_KEY not set. Assuming token is already decrypted.');
    return encryptedToken;
  }
  
  try {
    const fernet = Fernet(ENCRYPTION_KEY);
    const decrypted = fernet.decrypt(encryptedToken);
    return decrypted.toString('utf-8');
  } catch (error) {
    console.error('[ERROR] Failed to decrypt token:', error);
    throw new Error('Token decryption failed');
  }
}

/**
 * Verify and decode a JWT token
 */
function verifyToken(token) {
  try {
    // Try to decrypt first (in case it's encrypted)
    let jwtToken = token;
    try {
      jwtToken = decryptToken(token);
    } catch (decryptError) {
      // If decryption fails, assume it's already a plain JWT token
      console.log('[DEBUG] Token decryption failed, trying as plain JWT');
    }
    
    // Verify and decode JWT
    const payload = jwt.verify(jwtToken, JWT_SECRET_KEY, {
      algorithms: [JWT_ALGORITHM]
    });
    
    return payload;
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      throw new Error('Token has expired');
    } else if (error.name === 'JsonWebTokenError') {
      throw new Error('Invalid token format');
    } else {
      throw new Error(`Token verification failed: ${error.message}`);
    }
  }
}

/**
 * Extract user information from token
 * Handles both shortened (uid, e, r) and full (user_id, email, module_role) field names
 */
function extractUserInfo(token) {
  const payload = verifyToken(token);
  
  // Support both shortened and full field names for backward compatibility
  const userId = payload.uid || payload.user_id;
  const email = payload.e || payload.email;
  const moduleRole = payload.r || payload.module_role || '';
  
  return {
    userId: userId,
    email: email,
    moduleRole: moduleRole,
    expiresAt: new Date(payload.exp * 1000),
    issuedAt: payload.iat ? new Date(payload.iat * 1000) : new Date((payload.exp - 86400) * 1000) // Default to 24h before exp if iat missing
  };
}

module.exports = {
  decryptToken,
  verifyToken,
  extractUserInfo
};
```

#### Python Version:

```python
import jwt
from cryptography.fernet import Fernet
import os
from dotenv import load_dotenv
from datetime import datetime

load_dotenv()

# Load from environment variables
JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY')
ENCRYPTION_KEY = os.environ.get('ENCRYPTION_KEY')
JWT_ALGORITHM = 'HS256'

def decrypt_token(encrypted_token: str) -> str:
    """
    Decrypt an encrypted token using Fernet.
    If ENCRYPTION_KEY is not set, returns token as-is (assuming already decrypted).
    """
    if not ENCRYPTION_KEY:
        print("[WARNING] ENCRYPTION_KEY not set. Assuming token is already decrypted.")
        return encrypted_token
    
    try:
        fernet = Fernet(ENCRYPTION_KEY.encode())
        decrypted_token = fernet.decrypt(encrypted_token.encode())
        return decrypted_token.decode()
    except Exception as e:
        print(f"[ERROR] Failed to decrypt token: {e}")
        raise Exception('Token decryption failed')

def verify_token(token: str) -> dict:
    """
    Verify and decode a JWT token.
    Handles both encrypted and plain JWT tokens.
    """
    try:
        # Try to decrypt first (in case it's encrypted)
        jwt_token = token
        try:
            jwt_token = decrypt_token(token)
        except:
            # If decryption fails, assume it's already a plain JWT token
            print("[DEBUG] Token decryption failed, trying as plain JWT")
        
        # Verify and decode JWT
        payload = jwt.decode(jwt_token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise Exception('Token has expired')
    except jwt.InvalidTokenError as e:
        raise Exception(f'Invalid token: {e}')

def extract_user_info(token: str) -> dict:
    """
    Extract user information from token.
    Handles both shortened (uid, e, r) and full (user_id, email, module_role) field names.
    Returns: {userId, email, moduleRole, expiresAt, issuedAt}
    """
    payload = verify_token(token)
    
    # Support both shortened and full field names for backward compatibility
    user_id = payload.get('uid') or payload.get('user_id')
    email = payload.get('e') or payload.get('email')
    module_role = payload.get('r') or payload.get('module_role', '')
    
    exp_timestamp = payload.get('exp')
    iat_timestamp = payload.get('iat')
    
    # If iat is missing, default to 24 hours before exp
    if not iat_timestamp and exp_timestamp:
        iat_timestamp = exp_timestamp - 86400
    
    return {
        'userId': user_id,
        'email': email,
        'moduleRole': module_role,
        'expiresAt': datetime.fromtimestamp(exp_timestamp) if exp_timestamp else None,
        'issuedAt': datetime.fromtimestamp(iat_timestamp) if iat_timestamp else None
    }
```

### Step 3: Extract Token from URL

#### React/Next.js Example:

```javascript
import { useSearchParams } from 'next/navigation';
import { useEffect, useState } from 'react';
import { extractUserInfo } from './token_utils';

export default function LandingScreen() {
  const searchParams = useSearchParams();
  const [userInfo, setUserInfo] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    const token = searchParams.get('token');
    
    if (token) {
      console.log('Landing screen: Token found in URL, starting validation...');
      
      try {
        // Validate token structure first
        if (!token || typeof token !== 'string' || token.trim().length === 0) {
          throw new Error('Invalid token structure: Token is empty or invalid');
        }
        
        // Extract user info from token
        const user = extractUserInfo(token);
        console.log('Landing screen: Token validated successfully', user);
        
        setUserInfo(user);
        
        // Proceed with auto-login
        handleAutoLogin(user);
      } catch (err) {
        console.error('Error validating token structure:', err);
        setError(err.message);
        console.log('Landing screen: Token is invalid or expired');
      }
    } else {
      console.log('Landing screen: No token found in URL');
    }
  }, [searchParams]);

  const handleAutoLogin = async (user) => {
    try {
      // Use the email from token to authenticate
      // This depends on your authentication system
      await authenticateUser(user.email, user.userId);
      
      // Redirect to dashboard or main app
      router.push('/dashboard');
    } catch (err) {
      console.error('Token authentication failed:', err.message);
      setError('Auto-login failed. Please log in manually.');
    }
  };

  // Rest of your component...
}
```

#### Vanilla JavaScript Example:

```javascript
// Extract token from URL query parameters
function getTokenFromURL() {
  const urlParams = new URLSearchParams(window.location.search);
  return urlParams.get('token');
}

// On page load
window.addEventListener('DOMContentLoaded', () => {
  const token = getTokenFromURL();
  
  if (token) {
    console.log('Landing screen: Starting token check...');
    
    try {
      // Validate token structure
      if (!token || typeof token !== 'string' || token.trim().length === 0) {
        throw new Error('Invalid token structure: Token is empty or invalid');
      }
      
      // Extract user info
      const userInfo = extractUserInfo(token);
      console.log('Landing screen: Token validated successfully', userInfo);
      
      // Proceed with auto-login
      handleAutoLogin(userInfo);
    } catch (error) {
      console.error('Error validating token structure:', error);
      console.log('Landing screen: Token is invalid or expired');
      console.log('Token authentication failed:', error.message);
    }
  }
});
```

### Step 4: Validate Token Against Database (Optional but Recommended)

Even after verifying the JWT, validate against your onboarding collection:

```javascript
async function validateTokenWithDatabase(userInfo) {
  try {
    // Query your onboarding collection (Firestore, MongoDB, etc.)
    const onboardingDoc = await db.collection('onboarding')
      .where('user_id', '==', userInfo.userId)
      .where('email', '==', userInfo.email)
      .limit(1)
      .get();
    
    if (onboardingDoc.empty) {
      throw new Error('User not found in onboarding collection');
    }
    
    const onboardingData = onboardingDoc.docs[0].data();
    
    // Optional: Verify token matches stored token
    if (onboardingData.token) {
      // Token should match (or be the same encrypted version)
      console.log('[DEBUG] Token validated against database');
    }
    
    return onboardingData;
  } catch (error) {
    console.error('[ERROR] Database validation failed:', error);
    throw error;
  }
}
```

### Step 5: Complete Auto-Login Flow

```javascript
async function handleAutoLogin(userInfo) {
  try {
    // Step 1: Token is already validated (JWT verified)
    console.log('Step 1: Token validated ✓');
    
    // Step 2: Validate against database (optional)
    const onboardingData = await validateTokenWithDatabase(userInfo);
    console.log('Step 2: Database validation ✓');
    
    // Step 3: Check user status (should be Active)
    if (onboardingData.status !== 'Active') {
      throw new Error(`User status is ${onboardingData.status}. Account must be Active.`);
    }
    console.log('Step 3: User status check ✓');
    
    // Step 4: Authenticate user in your app
    await authenticateUser({
      email: userInfo.email,
      userId: userInfo.userId,
      moduleRole: userInfo.moduleRole
    });
    console.log('Step 4: User authenticated ✓');
    
    // Step 5: Redirect to dashboard
    window.location.href = '/dashboard';
    
  } catch (error) {
    console.error('Auto-login failed:', error);
    // Show error message or redirect to manual login
    showError('Auto-login failed. Please log in manually.');
  }
}
```

## Error Handling

### Common Errors and Solutions:

1. **"Invalid token structure: FormatException"**
   - **Cause:** Token is not a valid string or is empty
   - **Solution:** Check URL parameter extraction and ensure token exists

2. **"Token decryption failed"**
   - **Cause:** ENCRYPTION_KEY is incorrect or token format is wrong
   - **Solution:** Verify ENCRYPTION_KEY matches Khonobuzz backend

3. **"Token has expired"**
   - **Cause:** Token expiration time has passed
   - **Solution:** User needs to log in again from Khonobuzz app

4. **"Invalid token: Invalid signature"**
   - **Cause:** JWT_SECRET_KEY doesn't match
   - **Solution:** Verify JWT_SECRET_KEY matches Khonobuzz backend

5. **"User not found in onboarding collection"**
   - **Cause:** User doesn't exist in PDH database
   - **Solution:** Ensure user sync from Khonobuzz is working

## Testing

### Test Cases:

1. **Valid encrypted token** → Should decrypt, verify, and auto-login
2. **Expired token** → Should show error and redirect to manual login
3. **Invalid token format** → Should show error
4. **Missing token** → Should show normal landing screen
5. **Token with wrong encryption key** → Should show decryption error

### Test Token (for development):

You can test with a token from Khonobuzz backend logs or generate a test token using the same keys.

## Security Best Practices

1. **Always validate token expiration** - Don't accept expired tokens
2. **Verify JWT signature** - Ensures token wasn't tampered with
3. **Validate against database** - Double-check user exists and is active
4. **Use HTTPS** - Tokens should only be sent over secure connections
5. **Store keys securely** - Never commit encryption keys to version control
6. **Log security events** - Log failed authentication attempts

## Summary

**Required Steps:**
1. ✅ Set `JWT_SECRET_KEY` and `ENCRYPTION_KEY` in `.env` (must match Khonobuzz)
2. ✅ Install dependencies (`jsonwebtoken`, `cryptography`)
3. ✅ Create token utility functions (decrypt, verify, extract)
4. ✅ Extract token from URL query parameters
5. ✅ Validate token structure before processing
6. ✅ Decrypt token (if ENCRYPTION_KEY is set)
7. ✅ Verify JWT signature and expiration
8. ✅ Extract user info (email, userId, moduleRole)
9. ✅ Validate against database (optional but recommended)
10. ✅ Authenticate user and redirect to dashboard

**Key Points:**
- Tokens are **always encrypted** when sent from Khonobuzz
- You **MUST set ENCRYPTION_KEY** to decrypt tokens
- JWT_SECRET_KEY **MUST match** Khonobuzz backend
- Always validate token expiration
- Handle errors gracefully with fallback to manual login

This implementation ensures secure, reliable token-based auto-login for PDH users coming from the Khonobuzz app.

