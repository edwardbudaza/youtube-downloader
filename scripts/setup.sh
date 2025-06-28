#!/bin/bash
# Setup script for YouTube Downloader project

set -e

echo "Setting up project..."

# Get the root directory of the project
ROOT_DIR=$(dirname $(dirname $(realpath $0)))

# Install Python dependencies
echo "Installing Python dependencies..."
python -m pip install --upgrade pip
pip install -r $ROOT_DIR/src/requirements.txt

# Install Terraform
echo "Installing Terraform..."
TF_VERSION=1.5.0
wget https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip -O /tmp/terraform.zip
unzip /tmp/terraform.zip -d /tmp
sudo mv /tmp/terraform /usr/local/bin/
rm /tmp/terraform.zip

# Install AWS CLI
echo "Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

# Install yt-dlp
echo "Installing yt-dlp..."
sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp

echo "Setup complete!"