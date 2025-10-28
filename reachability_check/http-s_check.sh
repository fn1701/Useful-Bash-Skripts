#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW_BOLD='\033[1;33m'
NC='\033[0m' # No Color

# Text Style
NORMAL='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
UNDERLINE='\033[4m'

# Map HTTP status codes to standard messages
get_status_message() {
  local code=$1
  declare -A messages=(
    [200]="OK" [201]="Created" [202]="Accepted" [204]="No Content"
    [301]="Moved Permanently" [302]="Found" [303]="See Other"
    [304]="Not Modified" [307]="Temporary Redirect" [308]="Permanent Redirect"
    [400]="Bad Request" [401]="Unauthorized" [403]="Forbidden" [404]="Not Found"
    [500]="Internal Server Error" [502]="Bad Gateway" [503]="Service Unavailable" [504]="Gateway Timeout"
  )
  echo "${messages[$code]:-Unknown Status}"
}

# Assign color based on status code
get_status_color() {
  local code=$1
  if [[ "$code" =~ ^2 ]]; then echo "$GREEN"
  elif [[ "$code" =~ ^3 ]]; then echo "$YELLOW"
  else echo "$RED"
  fi
}

# Check certificate status
get_cert_status() {
  local output=$1
  if grep -q 'SSL certificate verify ok' <<< "$output"; then
    echo -e "${GREEN}Valid${NC}"
  elif grep -q 'self-signed' <<< "$output"; then
    echo -e "${YELLOW}Self-signed${NC}"
  else
    echo -e "${RED}None${NC}"
  fi
}

# Perform a curl request with -4 or -6
check_url() {
  local ip_version=$1
  local url=$2

  output=$(curl -L -"$ip_version" -s -o /dev/null -w "%{http_code} %{url_effective}" -v --connect-timeout 2 "$url" 2>&1)
  read -r http_code url_effective <<< "$(echo "$output" | tail -n1)"

  if [ "$http_code" = "000" ]; then
    output=$(curl -k -L -"$ip_version" -s -o /dev/null -w "%{http_code} %{url_effective}" -v "$url" 2>&1)
    read -r http_code url_effective <<< "$(echo "$output" | tail -n1)"
  fi

  # Extract info
  resolved_ip=$(echo "$output" | grep -oP "IPv${ip_version}:\s+\K([0-9a-fA-F:.]{7,39})" | head -1)
  tls_info=$(echo "$output" | grep -oP 'SSL connection using \K.*' | head -1)
  cert_status=$(get_cert_status "$output")

  status_message=$(get_status_message "$http_code")
  color=$(get_status_color "$http_code")

  # Output
  echo -e "Resolved IPv$ip_version:      $resolved_ip"
  echo -e "TLS Info:           $tls_info"
  echo -e "Certificate:        $cert_status"
  echo -e "Effective URL:      $url_effective"
  echo -e "Final HTTP Code:    $http_code [${color}${BOLD}${status_message}${NC}]\n"
}

# Main

url="$1"
if [[ -z "$url" ]]; then
  echo "Usage: $0 <url>"
  exit 1
fi

extract_host() {
  local input="$1"
  input="${input#*://}"
  echo "${input%%[:/]*}"
}

host=$(extract_host "$url")

# nslookup host to avoid IPv6 curl errors
nslookup "$host" &>/dev/null

echo -e "Checking:           "${BOLD}"$url"${NC}"\n"

check_url 4 "$url"
check_url 6 "$url"
