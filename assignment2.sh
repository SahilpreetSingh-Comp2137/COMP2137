#!/bin/bash

# Exit if not run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

echo "=== Starting server configuration ==="

# Network Configuration
echo "Checking network configuration..."
# Create/update netplan configuration
cat << EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses: [192.168.16.21/24]
EOF

# Fix permissions
chmod 600 /etc/netplan/01-netcfg.yaml

# Apply network configuration
echo "Applying network configuration..."
netplan apply

# Update hosts file
echo "Updating /etc/hosts file..."
# Remove any existing server1 entries
sed -i '/server1/d' /etc/hosts
# Add new entry
echo "192.168.16.21 server1" >> /etc/hosts

# Install software
echo "Installing required software..."
apt-get update
# Install apache2
if ! dpkg -l | grep -q "^ii.*apache2\s"; then
    echo "Installing apache2..."
    apt-get install -y apache2
else
    echo "apache2 is already installed"
fi

# Install squid
if ! dpkg -l | grep -q "^ii.*squid\s"; then
    echo "Installing squid..."
    apt-get install -y squid
else
    echo "squid is already installed"
fi

# Ensure services are enabled and running
echo "Enabling and starting services..."
systemctl enable apache2
systemctl start apache2
systemctl enable squid
systemctl start squid

# User management
echo "Setting up user accounts..."

# List of users to create
users=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")

for username in "${users[@]}"; do
    echo "Processing user: $username"
    
    # Create user if it doesn't exist
    if ! id -u "$username" &>/dev/null; then
        useradd -m -s /bin/bash "$username"
        echo "Created user: $username"
    else
        # Ensure home directory exists
        if [ ! -d "/home/$username" ]; then
            mkdir -p "/home/$username"
            chown "$username:$username" "/home/$username"
        fi
        
        # Ensure bash is the default shell
        if ! grep -q "^$username.*bash" /etc/passwd; then
            usermod -s /bin/bash "$username"
        fi
    fi
    
    # Add dennis to sudo group
    if [ "$username" = "dennis" ]; then
        if ! groups dennis | grep -q "\bsudo\b"; then
            usermod -aG sudo dennis
            echo "Added dennis to sudo group"
        fi
    fi
    
    # Set up SSH keys
    home_dir="/home/$username"
    ssh_dir="$home_dir/.ssh"
    
    # Create SSH directory if it doesn't exist
    if [ ! -d "$ssh_dir" ]; then
        mkdir -p "$ssh_dir"
    fi
    
    # Set proper permissions
    chmod 700 "$ssh_dir"
    chown "$username:$username" "$ssh_dir"
    
    # Generate RSA key if it doesn't exist
    if [ ! -f "$ssh_dir/id_rsa" ]; then
        echo "Generating RSA key for $username..."
        sudo -u "$username" ssh-keygen -t rsa -N "" -f "$ssh_dir/id_rsa"
    fi
    
    # Generate ED25519 key if it doesn't exist
    if [ ! -f "$ssh_dir/id_ed25519" ]; then
        echo "Generating ED25519 key for $username..."
        sudo -u "$username" ssh-keygen -t ed25519 -N "" -f "$ssh_dir/id_ed25519"
    fi
    
    # Create authorized_keys file with user's public keys
    cat "$ssh_dir/id_rsa.pub" "$ssh_dir/id_ed25519.pub" > "$ssh_dir/authorized_keys"
    
    # Add special key for dennis
    if [ "$username" = "dennis" ]; then
        if ! grep -q "AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI" "$ssh_dir/authorized_keys"; then
            echo "Adding special key for dennis..."
            echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm" >> "$ssh_dir/authorized_keys"
        fi
    fi
    
    # Set proper permissions for authorized_keys
    chmod 600 "$ssh_dir/authorized_keys"
    chown "$username:$username" "$ssh_dir/authorized_keys"
done

echo "=== Server configuration complete ==="
