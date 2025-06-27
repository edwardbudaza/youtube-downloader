from enum import Enum
from typing import Dict, Any, Optional

class ErrorCode(Enum):
    # Authentication errors
    AUTH_FAILED = "AUTH_FAILED"
    INVALID_TOKEN = "INVALID_TOKEN"
    TOKEN_EXPIRED = "TOKEN_EXPIRED"
    FORBIDDEN = "FORBIDDEN"
    
    # Request errors
    INVALID_REQUEST = "INVALID_REQUEST"
    INVALID_URL = "INVALID_URL"
    UNSUPPORTED_FORMAT = "UNSUPPORTED_FORMAT"
    
    # Download errors
    DOWNLOAD_FAILED = "DOWNLOAD_FAILED"
    DOWNLOAD_TIMEOUT = "DOWNLOAD_TIMEOUT"
    VIDEO_UNAVAILABLE = "VIDEO_UNAVAILABLE"
    
    # System errors
    INTERNAL_ERROR = "INTERNAL_ERROR"
    SERVICE_UNAVAILABLE = "SERVICE_UNAVAILABLE"
    RATE_LIMIT_EXCEEDED = "RATE_LIMIT_EXCEEDED"
    
    # Resource errors
    NOT_FOUND = "NOT_FOUND"
    ALREADY_EXISTS = "ALREADY_EXISTS"
    QUOTA_EXCEEDED = "QUOTA_EXCEEDED"

class CustomException(Exception):
    def __init__(
        self,
        error_code: ErrorCode,
        message: str,
        details: Optional[Dict[str, Any]] = None,
        status_code: int = None
    ):
        self.error_code = error_code
        self.message = message
        self.details = details or {}
        self.status_code = status_code or self._get_default_status_code(error_code)
        super().__init__(self.message)

    def _get_default_status_code(self, error_code: ErrorCode) -> int:
        """Get default HTTP status code for error code"""
        status_map = {
            # 400 Bad Request
            ErrorCode.INVALID_REQUEST: 400,
            ErrorCode.INVALID_URL: 400,
            ErrorCode.UNSUPPORTED_FORMAT: 400,
            
            # 401 Unauthorized
            ErrorCode.AUTH_FAILED: 401,
            ErrorCode.INVALID_TOKEN: 401,
            ErrorCode.TOKEN_EXPIRED: 401,
            
            # 403 Forbidden
            ErrorCode.FORBIDDEN: 403,
            
            # 404 Not Found
            ErrorCode.NOT_FOUND: 404,
            ErrorCode.VIDEO_UNAVAILABLE: 404,
            
            # 409 Conflict
            ErrorCode.ALREADY_EXISTS: 409,
            
            # 422 Unprocessable Entity
            ErrorCode.DOWNLOAD_FAILED: 422,
            
            # 429 Too Many Requests
            ErrorCode.RATE_LIMIT_EXCEEDED: 429,
            ErrorCode.QUOTA_EXCEEDED: 429,
            
            # 500 Internal Server Error
            ErrorCode.INTERNAL_ERROR: 500,
            ErrorCode.DOWNLOAD_TIMEOUT: 500,
            
            # 503 Service Unavailable
            ErrorCode.SERVICE_UNAVAILABLE: 503,
        }
        return status_map.get(error_code, 500)

    def to_dict(self) -> Dict[str, Any]:
        """Convert exception to dictionary"""
        return {
            "error": self.error_code.value,
            "message": self.message,
            "details": self.details,
            "status_code": self.status_code
        }