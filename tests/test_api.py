import pytest
from src.utils.downloader import YouTubeDownloader
from src.utils.errors import CustomException, ErrorCode
from unittest.mock import MagicMock, patch

@pytest.fixture
def mock_downloader():
    mock_s3 = MagicMock()
    return YouTubeDownloader(mock_s3, "test-bucket")

@pytest.mark.asyncio
async def test_download_video(mock_downloader):
    with patch('yt_dlp.YoutubeDL') as mock_ydl:
        mock_ydl.return_value.extract_info.return_value = {
            'title': 'Test Video',
            'duration': 120,
            'uploader': 'Test User'
        }
        
        result = await mock_downloader.download_video(
            "https://youtube.com/watch?v=test",
            user_id="test-user"
        )
        
        assert "download_id" in result
        assert result["status"] == "started"

@pytest.mark.asyncio
async def test_get_video_info_failure(mock_downloader):
    with patch('yt_dlp.YoutubeDL') as mock_ydl:
        mock_ydl.return_value.extract_info.side_effect = Exception("Invalid URL")
        
        with pytest.raises(CustomException) as exc:
            await mock_downloader._get_video_info("invalid-url")
            
        assert exc.value.error_code == ErrorCode.INVALID_URL

def test_format_selector(mock_downloader):
    assert mock_downloader._get_format_selector("720p", "mp4") == "best[height<=720]"
    assert mock_downloader._get_format_selector("best", "mp3") == "bestaudio"