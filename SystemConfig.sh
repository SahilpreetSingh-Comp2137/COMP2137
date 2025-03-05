#!/bin/bash

# Ensure script runs with root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Network Configuration
# Check and update netplan configuration
current_ip=$(ip addr show | grep "inet 192.168.16" | awk '{print $2}' | cut -d/ -f1)
if [ "$current_ip" != "192.168.16.21" ]; then
    echo "Updating network configuration..."
    cat << EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses: [192.168.16.21/24]
EOF
    # Fix permissions on netplan file
    chmod 600 /etc/netplan/01-netcfg.yaml
    
    # Apply network changes with proper error handling
    echo "Applying network configuration..."
    # Check if systemd-networkd is running
    if systemctl is-active --quiet systemd-networkd; then
        netplan apply
    else
        # Start networkd if not running
        systemctl start systemd-networkd
        netplan apply
        # If still failing, try a different approach
        if [ $? -ne 0 ]; then
            echo "Using alternative network configuration method..."
            systemctl restart systemd-networkd
            # Fallback to manually applying without netplan
            ip addr add 192.168.16.21/24 dev eth0 || true
        fi
    fi
fi

# Update /etc/hosts
sed -i '/server1/d' /etc/hosts
echo "192.168.16.21 server1" >> /etc/hosts

# Software Installation
# Check and install required packages
echo "Checking and installing required software..."
apt-get update
# Install packages if not present
if ! dpkg -l apache2 | grep -q '^ii'; then
    apt-get install -y apache2
fi
if ! dpkg -l squid | grep -q '^ii'; then
    apt-get install -y squid
fi

# Ensure services are running
systemctl enable apache2
systemctl enable squid
systemctl restart apache2
systemctl restart squid

# User Configuration
# List of users to create
echo "Configuring user accounts..."
users=(
    "dennis:sudo"
    "aubrey"
    "captain"
    "snibbles"
    "brownie"
    "scooter"
    "sandy"
    "perrier"
    "cindy"
    "tiger"
    "yoda"
)

# Process each user
for user_entry in "${users[@]}"; do
    # Split user entry into username and sudo status
    IFS=':' read -r username sudo_status <<< "$user_entry"
    
    echo "Setting up user: $username"
    # Create user if not exists
    if ! id "$username" &>/dev/null; then
        useradd -m -s /bin/bash "$username"
    fi
    
    # Add to sudo group if specified
    if [ "$sudo_status" = "sudo" ]; then
        usermod -aG sudo "$username"
    fi
    
    # Prepare SSH directory
    home_dir=$(eval echo ~"$username")
    ssh_dir="$home_dir/.ssh"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    chown "$username:$username" "$ssh_dir"
    
    # Generate SSH keys if not exists
    if [ ! -f "$ssh_dir/id_rsa" ]; then
        sudo -u "$username" ssh-keygen -t rsa -N "" -f "$ssh_dir/id_rsa"
    fi
    
    if [ ! -f "$ssh_dir/id_ed25519" ]; then
        sudo -u "$username" ssh-keygen -t ed25519 -N "" -f "$ssh_dir/id_ed25519"
    fi
    
    # Create authorized_keys
    cat "$ssh_dir/id_rsa.pub" "$ssh_dir/id_ed25519.pub" > "$ssh_dir/authorized_keys"
    chmod 600 "$ssh_dir/authorized_keys"
    chown "$username:$username" "$ssh_dir/authorized_keys"
    
    # Add special SSH key for dennis
    if [ "$username" = "dennis" ]; then
        grep -q "AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI" "$ssh_dir/authorized_keys" || \
        echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm" >> "$ssh_dir/authorized_keys"
    fi
done

echo "Server configuration complete!"
