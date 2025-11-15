#------------------------------------------------------------------------------
# Outputs for EC2 Instance Module
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Public IP
#------------------------------------------------------------------------------
output "public_ip" {
  description = "Public IP of the VPN server"
  value       = aws_instance.vpn_server.public_ip
}

#------------------------------------------------------------------------------
# Instance ID
#------------------------------------------------------------------------------
output "instance_id" {
  description = "Instance ID of the VPN server"
  value       = aws_instance.vpn_server.id
}

#------------------------------------------------------------------------------
# Private Key
#------------------------------------------------------------------------------
output "private_key_pem" {
  description = "Generated private key for SSH access"
  value       = tls_private_key.vpn_key.private_key_pem
  sensitive   = true
}

#------------------------------------------------------------------------------
# Key Name
#------------------------------------------------------------------------------
output "key_name" {
  description = "Name of the generated key pair"
  value       = aws_key_pair.vpn_key.key_name
}

#---------------------------------------------------------------------------------------
# VPN server public IP
#---------------------------------------------------------------------------------------
output "vpn_server_public_ip" {
  value       = aws_instance.vpn_server.public_ip
  description = "Public IP of the deployed VPN server"
}


#---------------------------------------------------------------------------------------
# S3 Path to Private Key
#---------------------------------------------------------------------------------------
output "vpn_private_key_s3_object" {
  value       = aws_s3_bucket_object.vpn_private_key.id
  description = "S3 object path for VPN private key"
}
