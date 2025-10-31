#------------------------------------------------------------------------------
# Variables
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# AWS Region
#------------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

#------------------------------------------------------------------------------
# S3 Bucket Name
#------------------------------------------------------------------------------
variable "s3_bucket_name" {
  description = "Existing S3 bucket for storing VPN configs"
  type        = string
  default     = "my-vpn-configs-usernamezero-2025"
}

#------------------------------------------------------------------------------
# VPN Instance Type
#------------------------------------------------------------------------------
variable "vpn_instance_type" {
  description = "EC2 instance type for the VPN server"
  type        = string
  default     = "t3.micro"
}

#------------------------------------------------------------------------------
# Dynamo DB Table
#------------------------------------------------------------------------------
variable "dynamodb_table_name" {
  description = "DynamoDB table for Terraform state locking"
  type        = string
  default     = "terraform-locks"
}

#------------------------------------------------------------------------------
# Key Pair
#------------------------------------------------------------------------------
variable "key_pair_name" {
  description = "Name for the AWS key pair used for the VPN server"
  type        = string
  default     = "vpn-key"
}

#------------------------------------------------------------------------------
# SSH Public Key
#------------------------------------------------------------------------------
variable "ssh_public_key_path" {
  description = "Path to the public SSH key for the VPN server"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}
