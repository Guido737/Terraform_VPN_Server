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
resource "aws_key_pair" "vpn_key" {
  key_name   = var.key_pair_name
  public_key = file(var.ssh_public_key_path)
}

#---------------------------------------------------------------------------------------
# Security group for VPN
#---------------------------------------------------------------------------------------
resource "aws_security_group" "vpn_sg" {
  name        = "vpn-sg"
  description = "Allow SSH and WireGuard"

  #---------------------------------------------------------------------------------------
  # SSH access
  #---------------------------------------------------------------------------------------
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #---------------------------------------------------------------------------------------
  # WireGuard UDP access
  #---------------------------------------------------------------------------------------
  ingress {
    description = "WireGuard UDP"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #---------------------------------------------------------------------------------------
  # All outbound traffic
  #---------------------------------------------------------------------------------------
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
    Name = "Terraform-VPN-Server"
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
#---------------------------------------------------------------------------------------
