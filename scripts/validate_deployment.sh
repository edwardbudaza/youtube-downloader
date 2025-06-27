#!/bin/bash
# Validate deployment by testing API endpoints

set -e

API_URL=$(terraform -chdir=terraform output -raw api_gateway_url)

echo "Testing API at $API_URL..."

# Test health endpoint
HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health")
if [ "$HEALTH_RESPONSE" -ne 200 ]; then
  echo "Health check failed: HTTP $HEALTH_RESPONSE"
  exit 1
fi

# Test authentication
AUTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/download")
if [ "$AUTH_RESPONSE" -ne 401 ]; then
  echo "Authentication test failed: HTTP $AUTH_RESPONSE"
  exit 1
fi

echo "All tests passed successfully!"