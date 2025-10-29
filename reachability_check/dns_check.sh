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

usage() {
  cat <<EOF
Usage: $0 [OPTIONS] <domain> [dns_ip]

Options:
  -s, --short        Short, one-line output
  -h, --help         Show this help

Arguments:
  <domain>   Domain name to resolve
  [dns_ip]   Optional DNS server IP to use

Examples:
  $0 -s example.com
  $0 example.com 8.8.8.8
EOF
}

MODE="verbose"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--short) MODE="short"; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1"; usage; exit 2 ;;
    *) break ;;
  esac
done

if [[ $# -lt 1 ]]; then
  echo -e "${RED}${BOLD}Error:${NC} Missing required arguments."
  usage
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
  if [[ "$MODE" == "short" ]]; then
    echo -ne "[${RED}${BOLD}FAILED${NC}] nslookup $domain; DNS server not reachable."
  else
    echo -e "[${RED}${BOLD}FAILED${NC}] DNS server not reachable."
  fi
  exit 1
else
  if [[ "$MODE" == "short" ]]; then
    echo -ne "[${GREEN}${BOLD}OK${NC}] nslookup $domain; Server: $server; "
    [[ -n "$cname" ]] && echo -ne "Canonical: $cname; "
    echo -ne "Addresses: $ips"
  else
    echo -e "nslookup $domain $server [${GREEN}${BOLD}OK${NC}]"
    echo -e "Server:    $server"
    [[ -n "$cname" ]] && echo "Canonical: $cname"
    echo -e "Addresses: $ips"
  fi
fi