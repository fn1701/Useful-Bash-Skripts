#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Text Style
NORMAL='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
UNDERLINE='\033[4m'

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
