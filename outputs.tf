#------------------------------------------------------------------------------
# Outputs
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Public IP of VPN Server
#------------------------------------------------------------------------------
output "vpn_server_public_ip" {
  description = "Public IP address of the VPN server"
  value       = module.vpn_server.public_ip
}

#------------------------------------------------------------------------------
# EC2 Instance ID
#------------------------------------------------------------------------------
output "vpn_server_instance_id" {
  description = "Instance ID of the VPN server"
  value       = module.vpn_server.instance_id
}

#------------------------------------------------------------------------------
# S3 Bucket Name
#------------------------------------------------------------------------------
output "s3_bucket_name" {
  description = "Name of the S3 bucket storing VPN configs"
  value       = module.vpn_s3.s3_bucket_name
}

#------------------------------------------------------------------------------
# DynamoDB Table Name
#------------------------------------------------------------------------------
output "dynamodb_table_name" {
  description = "DynamoDB table name used for state locking"
  value       = module.terraform_lock.table_name
}

#------------------------------------------------------------------------------
# SSH Connection Info
#------------------------------------------------------------------------------
output "ssh_connection_info" {
  description = "Quick SSH connection command"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${module.vpn_server.public_ip}"
}

#------------------------------------------------------------------------------
# Server Public Key
#------------------------------------------------------------------------------
output "server_public_key" {
  description = "WireGuard server public key"
  value       = "X9l2X1CDdstM4RtCwV+gCE3BQ0ymT8bk2YbIjn7c9V8="
}

#------------------------------------------------------------------------------
# S3 Bucket URL
#------------------------------------------------------------------------------
output "s3_bucket_url" {
  description = "S3 bucket URL for client configs"
  value       = "s3://my-vpn-configs-usernamezero-2025"
}

#------------------------------------------------------------------------------
# Installed Scripts
#------------------------------------------------------------------------------
output "management_scripts_installed" {
  description = "WireGuard management scripts are installed on server"
  value       = true
}
