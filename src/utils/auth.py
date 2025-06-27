import os
import jwt
from datetime import datetime, timedelta
from dataclasses import dataclass
from typing import Optional
import logging

from .errors import CustomException, ErrorCode

logger = logging.getLogger(__name__)

@dataclass
class TokenData:
    user_id: str
    email: str
    permissions: list
    expires_at: datetime

class AuthManager:
    def __init__(self):
        self.secret_key = os.getenv('JWT_SECRET_KEY')
        self.algorithm = 'HS256'
        self.token_expiry_hours = int(os.getenv('TOKEN_EXPIRY_HOURS', '24'))
        
        if not self.secret_key:
            raise ValueError("JWT_SECRET_KEY environment variable is required")

    def generate_token(self, user_id: str, email: str, permissions: list = None) -> str:
        """Generate JWT token"""
        try:
            permissions = permissions or ['download']
            expires_at = datetime.utcnow() + timedelta(hours=self.token_expiry_hours)
            
            payload = {
                'user_id': user_id,
                'email': email,
                'permissions': permissions,
                'exp': expires_at,
                'iat': datetime.utcnow(),
                'iss': 'youtube-downloader'
            }
            
            token = jwt.encode(payload, self.secret_key, algorithm=self.algorithm)
            logger.info(f"Token generated for user: {user_id}")
            return token
            
        except Exception as e:
            logger.error(f"Token generation failed: {str(e)}")
            raise CustomException(
                ErrorCode.AUTH_FAILED,
                "Failed to generate authentication token",
                {"error": str(e)}
            )

    def verify_token(self, token: str) -> TokenData:
        """Verify JWT token"""
        try:
            payload = jwt.decode(
                token,
                self.secret_key,
                algorithms=[self.algorithm],
                options={"verify_exp": True}
            )
            
            return TokenData(
                user_id=payload['user_id'],
                email=payload['email'],
                permissions=payload.get('permissions', []),
                expires_at=datetime.fromtimestamp(payload['exp'])
            )
            
        except jwt.ExpiredSignatureError:
            raise CustomException(
                ErrorCode.TOKEN_EXPIRED,
                "Authentication token has expired"
            )
        except jwt.InvalidTokenError as e:
            raise CustomException(
                ErrorCode.INVALID_TOKEN,
                "Invalid authentication token",
                {"error": str(e)}
            )
        except Exception as e:
            logger.error(f"Token verification failed: {str(e)}")
            raise CustomException(
                ErrorCode.AUTH_FAILED,
                "Authentication failed",
                {"error": str(e)}
            )

# Global auth manager instance
auth_manager = AuthManager()

def verify_token(token: str) -> TokenData:
    """Convenience function to verify token"""
    return auth_manager.verify_token(token)

def generate_token(user_id: str, email: str, permissions: list = None) -> str:
    """Convenience function to generate token"""
    return auth_manager.generate_token(user_id, email, permissions)