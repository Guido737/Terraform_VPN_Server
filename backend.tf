#------------------------------------------------------------------------------
# S3 Bucket
#------------------------------------------------------------------------------

terraform {
  backend "s3" {
    bucket         = "my-vpn-configs-usernamezero-2025"
    key            = "terraform/state/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
