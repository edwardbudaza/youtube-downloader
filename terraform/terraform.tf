terraform {
  backend "s3" {
    # These values will be provided via backend configuration
    # bucket         = "your-terraform-state-bucket"
    # key            = "youtube-downloader/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "terraform-state-lock"
    # encrypt        = true
  }
}