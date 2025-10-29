#!/bin/bash

CONFIG_FILE="./color.conf"
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
else
  echo "$CONFIG_FILE file not found!" >&2
  exit 1
fi

# Global Variables
url="$1"

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

get_status_color() {
  local code=$1
  if [[ "$code" =~ ^2 ]]; then echo "$GREEN"
  elif [[ "$code" =~ ^3 ]]; then echo "$YELLOW"
  else echo "$RED"
  fi
}

get_cert_status() {
  local output=$1
  local url=$2
  if grep -q 'SSL certificate verify ok' <<< "$output"; then
    echo -e "${GREEN}Valid${NC}"
  elif grep -q 'Self-signed' <<< "$output"; then
    echo -e "${YELLOW}Self-signed${NC}"
  else
    if [[ "$url" =~ ^https:// ]]; then
      echo -e "${RED}None${NC}"
    else
      echo "None (non-HTTPS)"
    fi
  fi
}

extract_cert_dates() {
  local output="$1"
  local not_before not_after

  not_before=$(echo "$output" | grep -oP 'start date: \K.*' | head -1)
  not_after=$(echo "$output" | grep -oP 'expire date: \K.*' | head -1)

  if [[ -n "$not_before" && -n "$not_after" ]]; then
    echo -e "from ${GREEN}$not_before${NC} to ${GREEN}$not_after${NC}"
  fi
}

check_url() {
  local ip_version=$1
  local url=$2

  output=$(curl -"$ip_version" -s -o /dev/null -w '%{http_code}' -v --connect-timeout 2 "$url" 2>&1)
  #echo "$output"  # Debug line
  read -r http_code <<< "$(echo "$output" | tail -n1)"

  if [ "$http_code" = "000" ]; then
    output=$(curl -k -"$ip_version" -s -o /dev/null -w '%{http_code}' -v --connect-timeout 2 "$url" 2>&1)
    read -r http_code url_effective <<< "$(echo "$output" | tail -n1)"
  fi

  resolved_ip=$(echo "$output" | grep -oP "IPv${ip_version}:\s+\K([0-9a-fA-F:.]{7,39})" | head -1)
  tls_info=$(echo "$output" | grep -oP 'SSL connection using \K.*' | head -1)
  cert_status=$(get_cert_status "$output")
  location=$(echo "$output" | grep -ioP '(?<=< Location: ).*' | tr -d '\r')

  echo -e "Current URL:        $url"
  echo -e "Resolved IP:        $resolved_ip"
  if [[ "$url" =~ ^https:// ]]; then
    echo -e "TLS Info:           $tls_info"
    echo -e "Certificate:        $cert_status $(extract_cert_dates "$output")"
  fi
  color=$(get_status_color "$http_code")
  msg=$(get_status_message "$http_code")
  echo -e "Final HTTP Code:    ${color}$http_code${NC} [${color}${BOLD}${msg}${NC}]"
  # Check if $location is empty to break recursion
  if [[ -z "$location" ]]; then
    echo
    return
  else
    # If 'location' starts with '/', prepend the base URL to it
    if [[ "$location" =~ ^/ ]]; then
      base_url=$(echo "$url" | cut -d'/' -f1,2,3)  # Extract the base URL
      # echo "Base URL: $base_url"  # Debug line
      location="$base_url$location"
    fi
    echo -e "Next URL:           $location"
    echo
  fi

  # Avoid infinite loop if the location is the same as the current URL
  if [[ "$location" == "$url" ]]; then
    echo
    return
  fi

  check_url "$ip_version" "$location"
}

# Main

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
nslookup "$host" &>/dev/null

echo -e "${BOLD}Checking URL:${NC} $url"
echo

echo -e "${BOLD}IPv4 check:${NC}"
check_url 4 "$url"
echo -e "${BOLD}IPv6 check:${NC}"
check_url 6 "$url"
