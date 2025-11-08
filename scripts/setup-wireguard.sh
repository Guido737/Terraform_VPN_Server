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
# Generate server keys (только если их нет)
#------------------------------------------------------------------------------
if [ ! -f privatekey ] || [ ! -f publickey ]; then
    echo "Generating server keys..."
    sudo wg genkey | sudo tee privatekey | sudo wg pubkey | sudo tee publickey
    sudo chmod 600 privatekey
    sudo chmod 644 publickey
else
    echo "Server keys already exist, skipping generation"
fi

#------------------------------------------------------------------------------
# Configure AWS CLI
#------------------------------------------------------------------------------
mkdir -p ~/.aws
cat > ~/.aws/config << EOL
[default]
region = us-east-1
output = json
EOL

cat > ~/.aws/credentials << EOL
[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
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
# Run initial sync (если скрипт существует)
#------------------------------------------------------------------------------
if [ -f "/home/ubuntu/vpn-scripts/wg-sync-configs.sh" ]; then
    echo "Running initial configuration sync..."
    sudo /home/ubuntu/vpn-scripts/wg-sync-configs.sh
else
    echo "Warning: wg-sync-configs.sh not found, skipping initial sync"
fi

#------------------------------------------------------------------------------
# Enable IP forwarding
#------------------------------------------------------------------------------
echo "Enabling IP forwarding..."
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
fi
sudo sysctl -p

#------------------------------------------------------------------------------
# Start WireGuard service (только если конфиг существует)
#------------------------------------------------------------------------------
if [ -f "/etc/wireguard/wg0.conf" ]; then
    echo "Starting WireGuard service..."
    
    # Останавливаем если уже запущен
    sudo systemctl stop wg-quick@wg0 2>/dev/null || true
    sudo systemctl disable wg-quick@wg0 2>/dev/null || true
    
    # Перезагружаем демон и запускаем
    sudo systemctl daemon-reload
    sudo systemctl enable wg-quick@wg0
    sudo systemctl start wg-quick@wg0
else
    echo "Warning: wg0.conf not found, WireGuard service not started"
    echo "Run wg-sync-configs.sh manually to generate config"
fi

#------------------------------------------------------------------------------
# Check status
#------------------------------------------------------------------------------
echo "=== Setup Complete ==="
echo "WireGuard Status:"
sudo systemctl status wg-quick@wg0 --no-pager || echo "Service not running"
echo "Active Peers:"
sudo wg show 2>/dev/null || echo "No active WireGuard interface"