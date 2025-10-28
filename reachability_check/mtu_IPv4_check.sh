#!/bin/bash
# Script to check the maximum MTU size for IPv4 connectivity to a given host.
# Requires GNU/iputils-style ping with the -M option.
# Usage: ./mtu_IPv4_check.sh <hostname_or_ip>
# Example: ./mtu_IPv4_check.sh google.com

# Check if the first argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <hostname_or_ip>"
    exit 1
fi

for i in {1500..1000}; do
    if ping -4 -c 1 -s $(($i - 28)) -M probe $1 > /dev/null 2>&1; then
        echo -e "\nMTU: $i"
        break
    else echo -ne "."
    fi
done