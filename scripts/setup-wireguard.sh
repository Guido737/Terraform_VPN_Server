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
killall apt apt-get || true
rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock
dpkg --configure -a

echo "Starting WireGuard setup..."

#------------------------------------------------------------------------------
# Save empty iptables rules to prevent iptables-persistent prompts
#------------------------------------------------------------------------------
mkdir -p /etc/iptables
touch /etc/iptables/rules.v4 /etc/iptables/rules.v6
chmod 644 /etc/iptables/rules.v4 /etc/iptables/rules.v6

#------------------------------------------------------------------------------
# Install packages with retry
#------------------------------------------------------------------------------
echo "Updating packages and installing dependencies..."
for i in {1..3}; do
    rm -f /var/lib/dpkg/lock-frontend /var/cache/debconf/config.dat
    dpkg --configure -a || true

    if DEBIAN_FRONTEND=noninteractive apt-get update -y && \
       DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
           wireguard wireguard-tools qrencode iptables-persistent \
           -o Dpkg::Options::="--force-confdef" \
           -o Dpkg::Options::="--force-confold"; then
        echo "Packages installed successfully"
        break
    fi

    echo "Retrying package installation ($i/3)..."
    sleep 5
done

#------------------------------------------------------------------------------
# Create WireGuard directory and generate keys
#------------------------------------------------------------------------------

cd ~
mkdir -p /etc/wireguard
cd /etc/wireguard

#------------------------------------------------------------------------------
# Generate server keys
#------------------------------------------------------------------------------
if [ ! -f privatekey ] || [ ! -f publickey ]; then
    echo "Generating server keys..."
    umask 077
    wg genkey | tee privatekey | wg pubkey | tee publickey
    chmod 600 privatekey
    chmod 644 publickey
    echo "Server keys generated successfully"
else
    echo "Server keys already exist, skipping generation"
fi

#------------------------------------------------------------------------------
# Create WireGuard configuration FIRST (before AWS operations)
#------------------------------------------------------------------------------
WG_CONF="/etc/wireguard/wg0.conf"

# Always create or ensure config exists
if [ ! -f "$WG_CONF" ]; then
    echo "Creating WireGuard configuration..."
    
    # Read private key (we are still in /etc/wireguard)
    if [ ! -f privatekey ]; then
        echo "ERROR: Private key not found. Cannot create WireGuard config."
        exit 1
    fi
    
    PRIVATE_KEY=$(cat privatekey)
    
    # Determine default interface
    DEFAULT_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    [ -z "$DEFAULT_INTERFACE" ] && DEFAULT_INTERFACE="eth0"
    
    # Create WireGuard config
    cat > "$WG_CONF" << EOL
[Interface]
PrivateKey = $PRIVATE_KEY
Address = 10.0.0.1/24
ListenPort = 51820
SaveConfig = true
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $DEFAULT_INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $DEFAULT_INTERFACE -j MASQUERADE
EOL
    
    chmod 600 "$WG_CONF"
    echo "✅ WireGuard configuration created at $WG_CONF with interface: $DEFAULT_INTERFACE"
else
    echo "WireGuard config already exists at $WG_CONF"
fi

#------------------------------------------------------------------------------
# Return to home directory for AWS operations
#------------------------------------------------------------------------------
cd ~

#------------------------------------------------------------------------------
# Configure AWS CLI (optional - only if credentials are provided)
#------------------------------------------------------------------------------
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Configuring AWS CLI..."
    mkdir -p ~/.aws
    
    # Install awscli if not already installed
    if ! command -v aws &> /dev/null; then
        echo "Installing AWS CLI..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y awscli
    fi
    
    cat > ~/.aws/config << EOL
[default]
region = ${AWS_REGION:-us-east-1}
output = json
EOL

    cat > ~/.aws/credentials << EOL
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOL

    chmod 600 ~/.aws/credentials

    # Test AWS CLI configuration
    if aws sts get-caller-identity > /dev/null 2>&1; then
        echo "✅ AWS CLI authentication successful"
        
        #------------------------------------------------------------------------------
        # Create VPN scripts directory
        #------------------------------------------------------------------------------
        cd ~
        mkdir -p /home/ubuntu/vpn-scripts
        chown ubuntu:ubuntu /home/ubuntu/vpn-scripts
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
            echo "Retrying S3 download ($i/3)..."
            sleep 5
        done

        if ls /home/ubuntu/vpn-scripts/*.sh >/dev/null 2>&1; then
            chmod +x /home/ubuntu/vpn-scripts/*.sh
            echo "Scripts made executable"
        fi
    else
        echo "❌ AWS CLI authentication failed, skipping S3 operations"
    fi
else
    echo "AWS credentials not provided, skipping AWS CLI configuration and S3 operations"
fi

#------------------------------------------------------------------------------
# Run initial sync if scripts were downloaded
#------------------------------------------------------------------------------
if [ -f "/home/ubuntu/vpn-scripts/wg-sync-configs.sh" ]; then
    echo "Running initial configuration sync..."
    /home/ubuntu/vpn-scripts/wg-sync-configs.sh
fi

#------------------------------------------------------------------------------
# Enable IP forwarding
#------------------------------------------------------------------------------
echo "Enabling IP forwarding..."
grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
echo "IP forwarding enabled"

#------------------------------------------------------------------------------
# Configure UFW if active (optional)
#------------------------------------------------------------------------------
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "active"; then
    echo "Configuring UFW for WireGuard..."
    ufw allow 51820/udp
    echo "UFW configured for port 51820/udp"
fi

#------------------------------------------------------------------------------
# Ensure WireGuard kernel module is loaded
#------------------------------------------------------------------------------
echo "Loading WireGuard kernel module..."
modprobe wireguard 2>/dev/null || true

#------------------------------------------------------------------------------
# Start WireGuard service
#------------------------------------------------------------------------------
if [ -f "$WG_CONF" ]; then
    echo "Starting WireGuard service..."
    
    systemctl stop wg-quick@wg0 2>/dev/null || true
    systemctl reset-failed wg-quick@wg0 2>/dev/null || true

    systemctl enable wg-quick@wg0
    if systemctl start wg-quick@wg0; then
        echo "WireGuard service started successfully"
    else
        echo "WARNING: Failed to start WireGuard service, checking logs..."
        journalctl -u wg-quick@wg0 -n 10 --no-pager
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
systemctl status wg-quick@wg0 --no-pager --lines=5 || echo "Service status check failed"

echo "Active Peers:"
wg show 2>/dev/null || echo "No active WireGuard interface or command failed"

echo "Server Public Key:"
cat /etc/wireguard/publickey 2>/dev/null || echo "Public key not available"

#------------------------------------------------------------------------------
# Verify critical services and interface readiness
#------------------------------------------------------------------------------
echo "=== Verification ==="
systemctl is-active --quiet wg-quick@wg0 && echo "✅ WireGuard service is running" || echo "❌ WireGuard service is not running"
[ -f "$WG_CONF" ] && echo "✅ WireGuard config exists" || echo "❌ WireGuard config missing"

# Wait and verify wg0 interface
echo "Verifying wg0 interface readiness..."
for i in {1..5}; do
    if ip link show wg0 >/dev/null 2>&1 && wg show wg0 >/dev/null 2>&1; then
        echo "✅ wg0 interface is up and ready"
        WG_IP=$(ip -4 addr show wg0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -1)
        [ -n "$WG_IP" ] && echo "✅ wg0 interface IP: $WG_IP"
        break
    fi
    echo "Waiting for wg0 interface to be ready... ($i/5)"
    sleep 5
done

echo "WireGuard setup completed successfully!"