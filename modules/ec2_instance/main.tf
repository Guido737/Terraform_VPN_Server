#---------------------------------------------------------------------------------------
# Get Ubuntu 22.04 LTS AMI
#---------------------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

#---------------------------------------------------------------------------------------
# Key pair for VPN server
#---------------------------------------------------------------------------------------
resource "tls_private_key" "vpn_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "vpn_key" {
  key_name   = "${var.key_pair_name}-${terraform.workspace}"
  public_key = tls_private_key.vpn_key.public_key_openssh
}

#---------------------------------------------------------------------------------------
# Save private key locally (optional)
#---------------------------------------------------------------------------------------
resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.vpn_key.private_key_pem
  filename        = "${path.module}/../../../vpn_private_key_${terraform.workspace}.pem"
  file_permission = "0600"
}

#---------------------------------------------------------------------------------------
# Security group for VPN
#---------------------------------------------------------------------------------------
resource "aws_security_group" "vpn_sg" {
  name        = "${var.security_group_name}-${terraform.workspace}"
  description = "Allow SSH and WireGuard"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "WireGuard UDP"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#---------------------------------------------------------------------------------------
# EC2 instance for VPN
#---------------------------------------------------------------------------------------
resource "aws_instance" "vpn_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.vpn_instance_type
  key_name               = aws_key_pair.vpn_key.key_name
  vpc_security_group_ids = [aws_security_group.vpn_sg.id]

  tags = {
    Name = "Terraform-VPN-Server-${terraform.workspace}"
  }
}

#---------------------------------------------------------------------------------------
# Server-side encryption for existing S3 bucket
#---------------------------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "vpn_configs_encryption" {
  bucket = var.s3_bucket_name

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
