#!/bin/bash
# Validate deployment by testing API endpoints

set -e

# Get API URL from Terraform output
API_URL=$(terraform -chdir=terraform output -raw api_gateway_url)
echo -e "\nTesting API at $API_URL..."

# Test health endpoint
echo -e "\n[1] Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health")
if [ "$HEALTH_RESPONSE" -eq 200 ]; then
    HEALTH_BODY=$(curl -s "$API_URL/health")
    echo "✓ Health check passed"
    echo "Response: $HEALTH_BODY"
else
    echo "✗ Health check failed: HTTP $HEALTH_RESPONSE"
    echo "Full response:"
    curl -i "$API_URL/health"
    exit 1
fi

# Test authentication
echo -e "\n[2] Testing authentication..."
AUTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/download")
if [ "$AUTH_RESPONSE" -eq 401 ]; then
    echo "✓ Authentication test passed (received expected 401)"
else
    echo "✗ Authentication test failed:"
    echo "Expected HTTP 401 but got $AUTH_RESPONSE"
    echo "Full response:"
    curl -i "$API_URL/download"
    exit 1
fi

# Test with valid JWT (if available)
echo -e "\n[3] Testing authenticated request..."
JWT_SECRET=$(aws ssm get-parameter --name /youtube-downloader/dev/jwt-secret --with-decryption --query Parameter.Value --output text 2>/dev/null || true)
if [ -n "$JWT_SECRET" ]; then
    TEST_TOKEN=$(python3 -c "
import jwt, datetime
print(jwt.encode({
    'user_id': 'test-user',
    'email': 'test@example.com',
    'permissions': ['download'],
    'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=1)
}, '$JWT_SECRET', algorithm='HS256'))
")
    AUTHED_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TEST_TOKEN" "$API_URL/download")
    if [ "$AUTHED_RESPONSE" -ne 401 ] && [ "$AUTHED_RESPONSE" -ne 403 ]; then
        echo "✓ Authenticated request test passed"
    else
        echo "✗ Authenticated request failed with HTTP $AUTHED_RESPONSE"
        exit 1
    fi
else
    echo "⚠ Skipping JWT test (could not retrieve secret from SSM)"
fi

echo -e "\n✅ All tests passed successfully!"