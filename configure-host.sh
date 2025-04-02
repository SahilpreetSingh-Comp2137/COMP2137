#!/bin/bash

# Ignore TERM, HUP and INT signals
trap "" TERM HUP INT

# Initialize variables
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -verbose)
            VERBOSE=true
            shift
            ;;
        -name)
            HOSTNAME="$2"
            shift 2
            ;;
        -ip)
            IP_ADDRESS="$2"
            shift 2
            ;;
        -hostentry)
            HOST_NAME="$2"
            HOST_IP="$3"
            shift 3
            ;;
        *)
            echo "Error: Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to log if verbose
log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo "$1"
    fi
}

# Update hostname if requested
if [ -n "$HOSTNAME" ]; then
    CURRENT_HOSTNAME=$(hostname)
    if [ "$CURRENT_HOSTNAME" != "$HOSTNAME" ]; then
        echo "$HOSTNAME" > /etc/hostname
        hostname "$HOSTNAME"
        sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$HOSTNAME/g" /etc/hosts
        logger "Hostname changed from $CURRENT_HOSTNAME to $HOSTNAME"
        log_verbose "Hostname changed from $CURRENT_HOSTNAME to $HOSTNAME"
    else
        log_verbose "Hostname is already set to $HOSTNAME, no changes needed"
    fi
fi

# Update IP address if requested
if [ -n "$IP_ADDRESS" ]; then
    INTERFACE="ens3"
    CURRENT_IP=$(ip -4 addr show dev $INTERFACE 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    
    if [ "$CURRENT_IP" != "$IP_ADDRESS" ]; then
        # Create the netplan config file
        cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses: [$IP_ADDRESS/24]
EOF
        # Set proper permissions (600 - read/write only for owner)
        chmod 600 /etc/netplan/01-netcfg.yaml
        
        # Apply netplan configuration
        netplan apply
        
        logger "IP address changed from $CURRENT_IP to $IP_ADDRESS"
        log_verbose "IP address changed from $CURRENT_IP to $IP_ADDRESS"
    else
        log_verbose "IP address is already set to $IP_ADDRESS, no changes needed"
    fi
fi

# Update hosts entry if requested
if [ -n "$HOST_NAME" ] && [ -n "$HOST_IP" ]; then
    if grep -q "$HOST_IP.*$HOST_NAME" /etc/hosts; then
        log_verbose "Host entry for $HOST_NAME ($HOST_IP) already exists"
    else
        sed -i "/\s$HOST_NAME\s*$/d" /etc/hosts
        echo -e "$HOST_IP\t$HOST_NAME" >> /etc/hosts
        logger "Added/updated hosts entry: $HOST_IP $HOST_NAME"
        log_verbose "Added/updated hosts entry: $HOST_IP $HOST_NAME"
    fi
fi

exit 0
