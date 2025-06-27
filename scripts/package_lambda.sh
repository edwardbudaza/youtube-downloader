#!/bin/bash
# Package Lambda function for deployment

set -e

echo "Packaging Lambda function..."

# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r src/requirements.txt

# Package dependencies
mkdir -p package
cp -r venv/lib/python3.11/site-packages/* package/
cp -r src/* package/

# Create zip file
cd package
zip -r9 ../lambda_package.zip .
cd ..

# Clean up
rm -rf venv package

echo "Lambda package created: lambda_package.zip"