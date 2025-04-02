#!/bin/bash
# This script runs the configure-host.sh script to modify 2 servers and update the local /etc/hosts file

# Check for verbose flag
VERBOSE=""
if [[ "$1" == "-verbose" ]]; then
    VERBOSE="-verbose"
    echo "Running in verbose mode"
fi

# Make sure configure-host.sh is executable
chmod +x ./configure-host.sh

# Configure server1 (loghost)
echo "Configuring server1 (loghost)..."
scp configure-host.sh remoteadmin@server1-mgmt:/root
ssh remoteadmin@server1-mgmt -- /root/configure-host.sh $VERBOSE -name loghost -ip 192.168.16.3 -hostentry webhost 192.168.16.4
if [ $? -ne 0 ]; then
    echo "Error configuring server1"
    exit 1
fi

# Configure server2 (webhost)
echo "Configuring server2 (webhost)..."
scp configure-host.sh remoteadmin@server2-mgmt:/root
ssh remoteadmin@server2-mgmt -- /root/configure-host.sh $VERBOSE -name webhost -ip 192.168.16.4 -hostentry loghost 192.168.16.3
if [ $? -ne 0 ]; then
    echo "Error configuring server2"
    exit 1
fi

# Update local hosts file - using sudo for local operations
echo "Updating local hosts entries..."
sudo ./configure-host.sh $VERBOSE -hostentry loghost 192.168.16.3
sudo ./configure-host.sh $VERBOSE -hostentry webhost 192.168.16.4

echo "Configuration completed successfully"
