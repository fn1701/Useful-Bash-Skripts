#!/bin/bash

# Determine the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"

# Colors for output
CONFIG_FILE="$SCRIPT_DIR/color.conf"
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=./color.conf
    source "$CONFIG_FILE"
else
    echo "$CONFIG_FILE file not found!" >&2
    exit 1
fi

ipv="$1"

# Check required argument
if [[ -z "$ipv" ]]; then
    echo "Usage: $0 <ip_version>" >&2
    echo "  <ip_version>  4 or 6" >&2
    exit 1
fi

# Choose the appropriate color based on IP version
if [[ "$ipv" == "4" ]]; then
    echo "$IPv4Color"
elif [[ "$ipv" == "6" ]]; then
    echo "$IPv6Color"
else
    echo "$NC" # Fallback/default
fi