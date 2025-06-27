import os
import uuid
import asyncio
from datetime import datetime
from typing import Dict, Any, Optional, List
import logging
import json
from concurrent.futures import ThreadPoolExecutor
import yt_dlp
import boto3
from botocore.exceptions import ClientError

from .errors import CustomException, ErrorCode

logger = logging.getLogger(__name__)

class YouTubeDownloader:
    def __init__(self, s3_client, bucket_name: str):
        self.s3_client = s3_client
        self.bucket_name = bucket_name
        self.dynamodb = boto3.resource('dynamodb')
        self.downloads_table = self.dynamodb.Table(os.getenv('DOWNLOADS_TABLE_NAME', 'downloads'))
        self.executor = ThreadPoolExecutor(max_workers=2)

    async def download_video(
        self,
        video_url: str,
        quality: str = '720p',
        format_type: str = 'mp4',
        user_id: str = None
    ) -> Dict[str, Any]:
        """Download video from YouTube"""
        download_id = str(uuid.uuid4())
        
        try:
            # Create download record
            await self._create_download_record(download_id, video_url, user_id)
            
            # Get video info first
            video_info = await self._get_video_info(video_url)
            
            # Update record with video info
            await self._update_download_record(
                download_id,
                {'video_info': video_info, 'status': 'downloading'}
            )
            
            # Start download in background
            loop = asyncio.get_event_loop()
            download_task = loop.run_in_executor(
                self.executor,
                self._download_to_s3,
                video_url,
                quality,
                format_type,
                download_id
            )
            
            # Don't wait for completion, return immediately
            return {
                'download_id': download_id,
                'status': 'started',
                'video_info': video_info,
                'estimated_time': self._estimate_download_time(video_info)
            }
            
        except Exception as e:
            logger.error(f"Download initiation failed: {str(e)}")
            await self._update_download_record(
                download_id,
                {'status': 'failed', 'error': str(e)}
            )
            raise CustomException(
                ErrorCode.DOWNLOAD_FAILED,
                "Failed to initiate download",
                {"download_id": download_id, "error": str(e)}
            )

    async def _get_video_info(self, video_url: str) -> Dict[str, Any]:
        """Get video information without downloading"""
        try:
            ydl_opts = {
                'quiet': True,
                'no_warnings': True,
                'extract_flat': False,
            }
            
            loop = asyncio.get_event_loop()
            
            def extract_info():
                with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                    return ydl.extract_info(video_url, download=False)
            
            info = await loop.run_in_executor(self.executor, extract_info)
            
            return {
                'title': info.get('title', 'Unknown'),
                'duration': info.get('duration', 0),
                'uploader': info.get('uploader', 'Unknown'),
                'view_count': info.get('view_count', 0),
                'upload_date': info.get('upload_date', ''),
                'thumbnail': info.get('thumbnail', ''),
                'formats_available': len(info.get('formats', []))
            }
            
        except Exception as e:
            logger.error(f"Failed to extract video info: {str(e)}")
            raise CustomException(
                ErrorCode.INVALID_URL,
                "Failed to extract video information",
                {"url": video_url, "error": str(e)}
            )

    def _download_to_s3(
        self,
        video_url: str,
        quality: str,
        format_type: str,
        download_id: str
    ) -> Dict[str, Any]:
        """Download video and upload to S3"""
        temp_file = f"/tmp/{download_id}.{format_type}"
        s3_key = f"downloads/{download_id}/{download_id}.{format_type}"
        
        try:
            # Configure yt-dlp options
            ydl_opts = {
                'format': self._get_format_selector(quality, format_type),
                'outtmpl': temp_file,
                'writeinfojson': False,
                'writesubtitles': False,
                'writeautomaticsub': False,
                'ignoreerrors': False,
                'no_warnings': False,
                'extractaudio': format_type in ['mp3', 'aac'],
                'audioformat': format_type if format_type in ['mp3', 'aac'] else None,
                'audioquality': '192' if format_type in ['mp3', 'aac'] else None,
            }
            
            # Download video
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                ydl.download([video_url])
            
            # Upload to S3
            self.s3_client.upload_file(
                temp_file,
                self.bucket_name,
                s3_key,
                ExtraArgs={
                    'ContentType': self._get_content_type(format_type),
                    'Metadata': {
                        'download-id': download_id,
                        'original-url': video_url,
                        'format': format_type,
                        'quality': quality
                    }
                }
            )
            
            # Generate presigned URL (valid for 24 hours)
            download_url = self.s3_client.generate_presigned_url(
                'get_object',
                Params={'Bucket': self.bucket_name, 'Key': s3_key},
                ExpiresIn=86400  # 24 hours
            )
            
            # Update download record
            asyncio.create_task(
                self._update_download_record(download_id, {
                    'status': 'completed',
                    's3_key': s3_key,
                    'download_url': download_url,
                    'completed_at': datetime.utcnow().isoformat()
                })
            )
            
            # Clean up temp file
            if os.path.exists(temp_file):
                os.remove(temp_file)
                
            return {
                'download_id': download_id,
                'status': 'completed',
                'download_url': download_url
            }
            
        except Exception as e:
            logger.error(f"Download to S3 failed: {str(e)}")
            # Update record with error
            asyncio.create_task(
                self._update_download_record(download_id, {
                    'status': 'failed',
                    'error': str(e),
                    'failed_at': datetime.utcnow().isoformat()
                })
            )
            # Clean up temp file
            if os.path.exists(temp_file):
                os.remove(temp_file)
            raise

    async def _create_download_record(
        self,
        download_id: str,
        video_url: str,
        user_id: str
    ):
        """Create download record in DynamoDB"""
        try:
            self.downloads_table.put_item(
                Item={
                    'download_id': download_id,
                    'user_id': user_id,
                    'video_url': video_url,
                    'status': 'initiated',
                    'created_at': datetime.utcnow().isoformat(),
                    'ttl': int((datetime.utcnow().timestamp() + 7 * 24 * 3600))  # 7 days TTL
                }
            )
        except ClientError as e:
            logger.error(f"Failed to create download record: {str(e)}")
            raise

    async def _update_download_record(
        self,
        download_id: str,
        updates: Dict[str, Any]
    ):
        """Update download record in DynamoDB"""
        try:
            update_expression = "SET "
            expression_values = {}
            
            for key, value in updates.items():
                update_expression += f"{key} = :{key}, "
                expression_values[f":{key}"] = value
            
            update_expression = update_expression.rstrip(", ")
            
            self.downloads_table.update_item(
                Key={'download_id': download_id},
                UpdateExpression=update_expression,
                ExpressionAttributeValues=expression_values
            )
        except ClientError as e:
            logger.error(f"Failed to update download record: {str(e)}")

    async def get_download_status(self, download_id: str, user_id: str) -> Dict[str, Any]:
        """Get download status"""
        try:
            response = self.downloads_table.get_item(
                Key={'download_id': download_id}
            )
            
            if 'Item' not in response:
                raise CustomException(
                    ErrorCode.NOT_FOUND,
                    "Download not found"
                )
            
            item = response['Item']
            
            # Verify user owns this download
            if item.get('user_id') != user_id:
                raise CustomException(
                    ErrorCode.FORBIDDEN,
                    "Access denied"
                )
            
            return item
            
        except ClientError as e:
            logger.error(f"Failed to get download status: {str(e)}")
            raise CustomException(
                ErrorCode.INTERNAL_ERROR,
                "Failed to retrieve download status"
            )

    async def list_user_downloads(
        self,
        user_id: str,
        limit: int = 10,
        offset: int = 0
    ) -> Dict[str, Any]:
        """List user downloads"""
        try:
            # Note: This is a simplified implementation
            # In production, you'd want to use GSI for efficient querying
            response = self.downloads_table.scan(
                FilterExpression='user_id = :user_id',
                ExpressionAttributeValues={':user_id': user_id},
                Limit=limit
            )
            
            return {
                'downloads': response.get('Items', []),
                'count': len(response.get('Items', [])),
                'has_more': 'LastEvaluatedKey' in response
            }
            
        except ClientError as e:
            logger.error(f"Failed to list downloads: {str(e)}")
            raise CustomException(
                ErrorCode.INTERNAL_ERROR,
                "Failed to retrieve downloads"
            )

    def _get_format_selector(self, quality: str, format_type: str) -> str:
        """Get yt-dlp format selector"""
        quality_map = {
            '144p': 'worst[height<=144]',
            '240p': 'worst[height<=240]',
            '360p': 'best[height<=360]',
            '480p': 'best[height<=480]',
            '720p': 'best[height<=720]',
            '1080p': 'best[height<=1080]',
            'best': 'best'
        }
        
        if format_type in ['mp3', 'aac']:
            return 'bestaudio'
        
        return quality_map.get(quality, 'best[height<=720]')

    def _get_content_type(self, format_type: str) -> str:
        """Get content type for S3 upload"""
        content_types = {
            'mp4': 'video/mp4',
            'webm': 'video/webm',
            'mkv': 'video/x-matroska',
            'mp3': 'audio/mpeg',
            'aac': 'audio/aac'
        }
        return content_types.get(format_type, 'application/octet-stream')

    def _estimate_download_time(self, video_info: Dict[str, Any]) -> int:
        """Estimate download time in seconds"""
        duration = video_info.get('duration', 0)
        # Simple estimation: assume 1:1 ratio for download time
        # In reality, this depends on video quality, network speed, etc.
        return max(30, duration // 2)  # Minimum 30 seconds