# YouTube Downloader API

A serverless API for downloading YouTube videos built with AWS Lambda, API Gateway, S3, and DynamoDB.

## Features

- Secure JWT authentication
- Multiple quality and format options
- Background processing of downloads
- Download status tracking
- Presigned S3 URLs for secure access

## Architecture

![Architecture Diagram](docs/architecture.png)

## Deployment

### Prerequisites

- AWS Account
- Terraform 1.0+
- Python 3.11
- AWS CLI

### Setup

1. Clone the repository
2. Run setup script:
   ```bash
   chmod +x scripts/setup.sh
   ./scripts/setup.sh