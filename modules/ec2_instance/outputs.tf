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
