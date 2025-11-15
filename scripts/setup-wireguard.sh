#!/bin/bash

set -e

#------------------------------------------------------------------------------
# Ensure script is run as root
#------------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: This script must be run as root. Exiting."
  exit 1
fi

#------------------------------------------------------------------------------
# Ensure no apt locks and fix dpkg
#------------------------------------------------------------------------------
sudo killall apt apt-get || true
sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock
sudo dpkg --configure -a

echo "Starting WireGuard setup..."

#------------------------------------------------------------------------------
# Install required packages with retry
#------------------------------------------------------------------------------
echo "Updating packages and installing dependencies..."
export DEBIAN_FRONTEND=noninteractive

for i in {1..3}; do
    sudo rm -f /var/lib/dpkg/lock-frontend /var/cache/debconf/config.dat
    sudo dpkg --configure -a

    if sudo apt-get update -y && \
       sudo apt-get install -y wireguard qrencode awscli iptables-persistent; then
        echo "Packages installed successfully"
        break
    fi

    if [ $i -eq 3 ]; then
        echo "ERROR: Failed to install packages after 3 attempts, skipping iptables-persistent"
        sudo apt-get install -y --no-install-recommends iptables-persistent || echo "⚠️ iptables-persistent installation skipped"
        break
    fi

    echo "Retrying package installation ($i/3)..."
    sleep 5
done



#------------------------------------------------------------------------------
# Create WireGuard directory
#------------------------------------------------------------------------------
sudo mkdir -p /etc/wireguard
cd /etc/wireguard

#------------------------------------------------------------------------------
# Ensure VPN private key exists (already uploaded via GitHub Actions)
#------------------------------------------------------------------------------
if [ ! -f /home/ubuntu/.ssh/vpn_key ]; then
    echo "ERROR: VPN private key not found at /home/ubuntu/.ssh/vpn_key"
    exit 1
fi
chmod 600 /home/ubuntu/.ssh/vpn_key
echo "✅ VPN private key is ready"

#------------------------------------------------------------------------------
# Generate server keys
#------------------------------------------------------------------------------
if [ ! -f privatekey ] || [ ! -f publickey ]; then
    echo "Generating server keys..."
    sudo wg genkey | sudo tee privatekey | sudo wg pubkey | sudo tee publickey
    sudo chmod 600 privatekey
    sudo chmod 644 publickey
    echo "Server keys generated successfully"
else
    echo "Server keys already exist, skipping generation"
fi


#------------------------------------------------------------------------------
# Configure AWS CLI
#------------------------------------------------------------------------------
echo "Configuring AWS CLI..."
mkdir -p ~/.aws
cat > ~/.aws/config << EOL
[default]
region = us-east-1
output = json
EOL

# Validate that AWS credentials are provided
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "ERROR: AWS credentials not provided in environment variables"
    exit 1
fi

cat > ~/.aws/credentials << EOL
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOL

chmod 600 ~/.aws/credentials
echo "AWS CLI configured"

# Test AWS CLI configuration
if aws sts get-caller-identity > /dev/null 2>&1; then
    echo "✅ AWS CLI authentication successful"
else
    echo "❌ AWS CLI authentication failed"
    exit 1
fi

#------------------------------------------------------------------------------
# Create VPN scripts directory
#------------------------------------------------------------------------------
sudo mkdir -p /home/ubuntu/vpn-scripts
sudo chown ubuntu:ubuntu /home/ubuntu/vpn-scripts
echo "Created VPN scripts directory"

#------------------------------------------------------------------------------
# Download setup scripts from S3 with retry
#------------------------------------------------------------------------------
echo "Downloading scripts from S3..."
for i in {1..3}; do
    if aws s3 cp s3://my-vpn-configs-usernamezero-2025/scripts/ /home/ubuntu/vpn-scripts/ --recursive --exclude "*" --include "*.sh"; then
        echo "Scripts downloaded successfully"
        break
    fi
    if [ $i -eq 3 ]; then
        echo "WARNING: Failed to download scripts from S3 after 3 attempts"
        break
    fi
    echo "Retrying S3 download ($i/3)..."
    sleep 5
done

if ls /home/ubuntu/vpn-scripts/*.sh >/dev/null 2>&1; then
    sudo chmod +x /home/ubuntu/vpn-scripts/*.sh
    echo "Scripts made executable"
fi

#------------------------------------------------------------------------------
# Run initial sync or auto-generate config
#------------------------------------------------------------------------------
WG_CONF="/etc/wireguard/wg0.conf"

if [ -f "/home/ubuntu/vpn-scripts/wg-sync-configs.sh" ]; then
    echo "Running initial configuration sync..."
    sudo /home/ubuntu/vpn-scripts/wg-sync-configs.sh
elif [ ! -f "$WG_CONF" ]; then
    echo "wg-sync-configs.sh not found, auto-generating basic wg0.conf..."
    PRIVATE_KEY=$(sudo cat privatekey 2>/dev/null || echo "")
    if [ -z "$PRIVATE_KEY" ]; then
        echo "ERROR: Cannot read private key for auto-config"
        exit 1
    fi
    
    # Detect network interface for iptables rules
    DEFAULT_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -z "$DEFAULT_INTERFACE" ]; then
        DEFAULT_INTERFACE="eth0"
    fi
    
    cat > "$WG_CONF" << EOL
[Interface]
PrivateKey = $PRIVATE_KEY
Address = 10.0.0.1/24
ListenPort = 51820
SaveConfig = true
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $DEFAULT_INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $DEFAULT_INTERFACE -j MASQUERADE
EOL
    sudo chmod 600 "$WG_CONF"
    echo "Basic wg0.conf generated with interface: $DEFAULT_INTERFACE"
else
    echo "WireGuard config already exists"
fi

#------------------------------------------------------------------------------
# Enable IP forwarding
#------------------------------------------------------------------------------
echo "Enabling IP forwarding..."
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
    echo "IP forwarding added to sysctl.conf"
fi
sudo sysctl -p
echo "IP forwarding enabled"

#------------------------------------------------------------------------------
# Configure UFW if active (optional)
#------------------------------------------------------------------------------
if command -v ufw >/dev/null 2>&1 && sudo ufw status | grep -q "active"; then
    echo "Configuring UFW for WireGuard..."
    sudo ufw allow 51820/udp
    echo "UFW configured for port 51820/udp"
fi

#------------------------------------------------------------------------------
# Ensure WireGuard kernel module is loaded
#------------------------------------------------------------------------------
echo "Loading WireGuard kernel module..."
sudo modprobe wireguard 2>/dev/null || true

#------------------------------------------------------------------------------
# Start WireGuard service
#------------------------------------------------------------------------------
if [ -f "$WG_CONF" ]; then
    echo "Starting WireGuard service..."
    
    # Stop if running and reset failed state
    sudo systemctl stop wg-quick@wg0 2>/dev/null || true
    sudo systemctl reset-failed wg-quick@wg0 2>/dev/null || true
    


    sudo systemctl enable wg-quick@wg0
    if sudo systemctl start wg-quick@wg0; then
        echo "WireGuard service started successfully"
    else
        echo "WARNING: Failed to start WireGuard service, checking logs..."
        sudo journalctl -u wg-quick@wg0 -n 10 --no-pager
        exit 1
    fi
else
    echo "ERROR: WireGuard config not found at $WG_CONF"
    exit 1
fi

#------------------------------------------------------------------------------
# Check status and verify interface
#------------------------------------------------------------------------------
echo "=== Setup Complete ==="
echo "WireGuard Status:"
sudo systemctl status wg-quick@wg0 --no-pager --lines=5 || echo "Service status check failed"

echo "Active Peers:"
sudo wg show 2>/dev/null || echo "No active WireGuard interface or command failed"

echo "Server Public Key:"
sudo cat /etc/wireguard/publickey 2>/dev/null || echo "Public key not available"

#------------------------------------------------------------------------------
# Verify critical services and interface readiness
#------------------------------------------------------------------------------
echo "=== Verification ==="
if sudo systemctl is-active --quiet wg-quick@wg0; then
    echo "✅ WireGuard service is running"
else
    echo "❌ WireGuard service is not running"
fi

if [ -f "$WG_CONF" ]; then
    echo "✅ WireGuard config exists"
else
    echo "❌ WireGuard config missing"
fi

# Wait and verify wg0 interface
echo "Verifying wg0 interface readiness..."
for i in {1..5}; do
    if ip link show wg0 >/dev/null 2>&1 && sudo wg show wg0 >/dev/null 2>&1; then
        echo "✅ wg0 interface is up and ready"
        WG_IP=$(ip -4 addr show wg0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -1)
        if [ -n "$WG_IP" ]; then
            echo "✅ wg0 interface IP: $WG_IP"
        fi
        break
    fi
    echo "Waiting for wg0 interface to be ready... ($i/5)"
    sleep 5
    if [ $i -eq 5 ]; then
        echo "⚠️ wg0 interface did not become ready in time"
        echo "Checking systemd logs..."
        sudo journalctl -u wg-quick@wg0 -n 20 --no-pager
    fi
done

echo " WireGuard setup completed successfully!"