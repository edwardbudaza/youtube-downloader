import pytest
from unittest.mock import MagicMock, patch
from src.lambda_function import app
from src.utils.errors import CustomException, ErrorCode
from fastapi.testclient import TestClient

client = TestClient(app)

def test_health_check():
    with patch('boto3.client') as mock_boto:
        mock_s3 = MagicMock()
        mock_boto.return_value = mock_s3
        
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json()["status"] == "healthy"

def test_download_endpoint_unauthorized():
    response = client.post("/download", json={"url": "https://youtube.com/watch?v=dQw4w9WgXcQ"})
    assert response.status_code == 401
    assert response.json()["error"] == "AUTH_FAILED"

def test_download_endpoint_missing_url():
    with patch('src.lambda_function.verify_token', return_value={"user_id": "test"}):
        response = client.post(
            "/download",
            json={},
            headers={"Authorization": "Bearer test"}
        )
        assert response.status_code == 400
        assert response.json()["error"] == "INVALID_REQUEST"

@pytest.mark.asyncio
async def test_custom_exception_handler():
    test_exception = CustomException(
        ErrorCode.INVALID_URL,
        "Invalid URL",
        {"url": "test"}
    )
    
    with patch('src.lambda_function.verify_token', side_effect=test_exception):
        response = client.post(
            "/download",
            json={"url": "invalid"},
            headers={"Authorization": "Bearer invalid"}
        )
        assert response.status_code == 400
        assert response.json()["error"] == "INVALID_URL"