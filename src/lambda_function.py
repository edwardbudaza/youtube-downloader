import json
import os
import logging
import traceback
from typing import Dict, Any, Optional
from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.security import HTTPBearer
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from mangum import Mangum
import boto3
from botocore.exceptions import BotoCoreError, ClientError
import jwt
from datetime import datetime, timedelta

from utils.auth import verify_token, TokenData
from utils.downloader import YouTubeDownloader
from utils.errors import CustomException, ErrorCode

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="YouTube Downloader API",
    description="Secure API for downloading YouTube videos",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security
security = HTTPBearer()

# Global variables
s3_client = None
downloader = None

def init_services():
    """Initialize AWS services and utilities"""
    global s3_client, downloader
    try:
        s3_client = boto3.client('s3')
        downloader = YouTubeDownloader(s3_client, os.getenv('S3_BUCKET_NAME'))
        logger.info("Services initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize services: {str(e)}")
        raise

# Initialize services on startup
init_services()

@app.exception_handler(CustomException)
async def custom_exception_handler(request: Request, exc: CustomException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.error_code.value,
            "message": exc.message,
            "details": exc.details,
            "timestamp": datetime.utcnow().isoformat()
        }
    )

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {str(exc)}\n{traceback.format_exc()}")
    return JSONResponse(
        status_code=500,
        content={
            "error": "INTERNAL_SERVER_ERROR",
            "message": "An unexpected error occurred",
            "timestamp": datetime.utcnow().isoformat()
        }
    )

async def get_current_user(token: str = Depends(security)) -> TokenData:
    """Validate JWT token and return user data"""
    try:
        return verify_token(token.credentials)
    except Exception as e:
        logger.error(f"Token validation failed: {str(e)}")
        raise HTTPException(
            status_code=401,
            detail="Invalid authentication credentials"
        )

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        # Test S3 connection
        s3_client.head_bucket(Bucket=os.getenv('S3_BUCKET_NAME'))
        
        return {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "services": {
                "s3": "connected",
                "lambda": "running"
            }
        }
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "timestamp": datetime.utcnow().isoformat(),
                "error": str(e)
            }
        )

@app.post("/download")
async def download_video(
    request: Dict[str, Any],
    current_user: TokenData = Depends(get_current_user)
):
    """Download YouTube video endpoint"""
    try:
        # Validate request
        if not request.get('url'):
            raise CustomException(
                ErrorCode.INVALID_REQUEST,
                "Video URL is required",
                {"field": "url"}
            )
        
        video_url = request['url']
        quality = request.get('quality', '720p')
        format_type = request.get('format', 'mp4')
        
        logger.info(f"Download request for URL: {video_url} by user: {current_user.user_id}")
        
        # Download video
        result = await downloader.download_video(
            video_url=video_url,
            quality=quality,
            format_type=format_type,
            user_id=current_user.user_id
        )
        
        return {
            "status": "success",
            "message": "Video downloaded successfully",
            "data": result,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except CustomException:
        raise
    except Exception as e:
        logger.error(f"Download failed: {str(e)}\n{traceback.format_exc()}")
        raise CustomException(
            ErrorCode.DOWNLOAD_FAILED,
            "Failed to download video",
            {"error": str(e)}
        )

@app.get("/downloads/{download_id}")
async def get_download_status(
    download_id: str,
    current_user: TokenData = Depends(get_current_user)
):
    """Get download status"""
    try:
        status = await downloader.get_download_status(download_id, current_user.user_id)
        return {
            "status": "success",
            "data": status,
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Failed to get download status: {str(e)}")
        raise CustomException(
            ErrorCode.NOT_FOUND,
            "Download not found",
            {"download_id": download_id}
        )

@app.get("/downloads")
async def list_downloads(
    current_user: TokenData = Depends(get_current_user),
    limit: int = 10,
    offset: int = 0
):
    """List user downloads"""
    try:
        downloads = await downloader.list_user_downloads(
            current_user.user_id,
            limit=limit,
            offset=offset
        )
        return {
            "status": "success",
            "data": downloads,
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Failed to list downloads: {str(e)}")
        raise CustomException(
            ErrorCode.INTERNAL_ERROR,
            "Failed to retrieve downloads",
            {"error": str(e)}
        )

# Lambda handler
handler = Mangum(app, lifespan="off")