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

domain="$1"
dns_ip="$2"

# Run nslookup and capture output
output=$(nslookup "$domain" ${dns_ip:+$dns_ip} 2>/dev/null)

# Extract server line
server=$(echo "$output" | awk '/^Server:/ {print $2}')

# Extract canonical name (CNAME), if any
cname=$(echo "$output" | sed -n 's/.*canonical name = \(.*\)\./\1/p')

# Extract IP addresses (A and AAAA records)
ips=$(echo "$output" | awk '/^Address: / {print $2}' | paste -sd ' ')

# Check if DNS server was reachable
if [[ -z "$output" || -z "$server" ]]; then
  echo -ne "[${RED}${BOLD}FAILED${NC}] "
  exit 1
else
  echo -ne "[${GREEN}${BOLD}OK${NC}] "
fi

# Print command
echo -ne "nslookup $domain; "

# Output
echo -ne "Server: $server; "
[[ -n "$cname" ]] && echo -ne "Canonical: $cname; "
echo -ne "Addresses: $ips"
