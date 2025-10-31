#------------------------------------------------------------------------------
# AWS provider configuration
#------------------------------------------------------------------------------
provider "aws" {
  region                      = "us-east-1"
  skip_credentials_validation = false
  skip_metadata_api_check     = false
  skip_requesting_account_id  = false
}


#------------------------------------------------------------------------------
# EC2 Instance Module
#------------------------------------------------------------------------------
module "vpn_server" {
  source              = "./modules/ec2_instance"
  vpn_instance_type   = var.vpn_instance_type
  key_pair_name       = var.key_pair_name
  ssh_public_key_path = var.ssh_public_key_path
  security_group_name = "vpn-sg"
}

#------------------------------------------------------------------------------
# S3 Bucket Module
#------------------------------------------------------------------------------
module "vpn_s3" {
  source      = "./modules/s3_bucket"
  bucket_name = var.s3_bucket_name
}

#------------------------------------------------------------------------------
# DynamoDB Lock Module
#------------------------------------------------------------------------------
module "terraform_lock" {
  source     = "./modules/dynamodb_lock"
  table_name = var.dynamodb_table_name
}

