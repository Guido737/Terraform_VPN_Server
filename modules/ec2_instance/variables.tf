#------------------------------------------------------------------------------
# Variables for ec2_instance module
#------------------------------------------------------------------------------
variable "vpn_instance_type" {
  description = "EC2 instance type for VPN server"
  type        = string
  default     = "t3.micro"
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

#------------------------------------------------------------------------------
# SECURITY GROUP
#------------------------------------------------------------------------------
variable "security_group_name" {
  description = "Security group name to create"
  type        = string
}

#------------------------------------------------------------------------------
# S3 Bucket Name
#------------------------------------------------------------------------------
variable "s3_bucket_name" {
  description = "Existing S3 bucket for storing VPN configs"
  type        = string
  default     = "my-vpn-configs-usernamezero-2025"
}
