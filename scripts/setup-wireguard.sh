#!/bin/bash

set -e

echo "Starting WireGuard setup..."

#------------------------------------------------------------------------------
# Install required packages
#------------------------------------------------------------------------------
sudo apt update
sudo apt install -y wireguard qrencode iptables-persistent awscli

#------------------------------------------------------------------------------
# Create WireGuard directory
#------------------------------------------------------------------------------
sudo mkdir -p /etc/wireguard
cd /etc/wireguard

#------------------------------------------------------------------------------
# Generate server keys
#------------------------------------------------------------------------------
echo "Generating server keys..."
sudo wg genkey | sudo tee privatekey | sudo wg pubkey | sudo tee publickey
sudo chmod 600 privatekey
sudo chmod 644 publickey

#------------------------------------------------------------------------------
# Configure AWS CLI
#------------------------------------------------------------------------------
mkdir -p ~/.aws
cat > ~/.aws/config << 'EOL'
[default]
region = us-east-1
output = json
EOL

cat > ~/.aws/credentials << 'EOL'
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOL

chmod 600 ~/.aws/credentials

#------------------------------------------------------------------------------
# Create VPN scripts directory
#------------------------------------------------------------------------------
sudo mkdir -p /home/ubuntu/vpn-scripts
sudo chown ubuntu:ubuntu /home/ubuntu/vpn-scripts

#------------------------------------------------------------------------------
# Download setup scripts from S3
#------------------------------------------------------------------------------
echo "Downloading scripts from S3..."
aws s3 cp s3://my-vpn-configs-usernamezero-2025/scripts/ /home/ubuntu/vpn-scripts/ --recursive --exclude "*" --include "*.sh"
sudo chmod +x /home/ubuntu/vpn-scripts/wg-*.sh

#------------------------------------------------------------------------------
# Run initial sync
#------------------------------------------------------------------------------
echo "Running initial configuration sync..."
sudo /home/ubuntu/vpn-scripts/wg-sync-configs.sh

#------------------------------------------------------------------------------
# Enable IP forwarding
#------------------------------------------------------------------------------
echo "Enabling IP forwarding..."
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

#------------------------------------------------------------------------------
# Start WireGuard service
#------------------------------------------------------------------------------
echo "Starting WireGuard service..."
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

#------------------------------------------------------------------------------
# Check status
#------------------------------------------------------------------------------
echo "=== Setup Complete ==="
echo "WireGuard Status:"
sudo systemctl status wg-quick@wg0 --no-pager
echo "Active Peers:"
sudo wg show