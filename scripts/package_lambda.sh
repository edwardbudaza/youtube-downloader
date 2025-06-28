#!/bin/bash
# Package Lambda function for deployment

set -e

echo "Packaging Lambda function..."

# Create virtual environment in parent directory
cd ..
python -m venv .venv
source .venv/bin/activate

# Install dependencies from src/requirements.txt
pip install -r src/requirements.txt -t package/
cp -r src/* package/

# Create zip file
cd package
zip -r9 ../lambda_package.zip .
cd ..

# Clean up
rm -rf package .venv

echo "Lambda package created: lambda_package.zip"