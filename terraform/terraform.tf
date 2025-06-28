terraform {
  backend "s3" {
    bucket         = "youtube-downloaderz"    # Your actual bucket name
    key            = "terraform.tfstate"      # Better path convention
    region         = "us-east-2"              # Must match bucket's region
    encrypt        = true
    use_lockfile   = true                     # Replaces dynamodb_table
  }
}