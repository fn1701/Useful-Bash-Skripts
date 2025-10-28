#!/usr/bin/env bash

# Unified http(s) checker
# Supports both the short and verbose outputs from the original two scripts

# Exit on unset vars only (avoid -e to allow curl failures to be handled)
set -u

CONFIG_FILE="./color.conf"
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck source=./color.conf
  source "$CONFIG_FILE"
else
  echo "$CONFIG_FILE file not found!" >&2
  exit 1
fi

usage() {
  cat <<EOF
Usage: $0 [OPTIONS] <url>

Options:
  -s, --short        Short, one-line output (like http-s_check_short.sh)
  -v, --verbose      Verbose multi-line output (default)
  -4                 Force IPv4
  -6                 Force IPv6
  -h, --help         Show this help

Examples:
  $0 https://example.com
  $0 -s -4 https://example.com
EOF
}

MODE=verbose
IP_FORCED=""  # either 4 or 6 or empty
TIMEOUT=2
DEBUG=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--short) MODE=short; shift ;;
    -v|--verbose) MODE=verbose; shift ;;
    -4) IP_FORCED=4; shift ;;
    -6) IP_FORCED=6; shift ;;
  -t) TIMEOUT="$2"; shift 2 ;;
  --timeout) TIMEOUT="$2"; shift 2 ;;
  --timeout=*) TIMEOUT="${1#*=}"; shift ;;
  -d|--debug) DEBUG=true; shift ;;
  -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1"; usage; exit 2 ;;
    *) break ;;
  esac
done

  if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

URL="$1"

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
  local output="$1"
  if grep -q 'SSL certificate verify ok' <<< "$output"; then
    echo -e "${GREEN}Valid${NC}"
  elif grep -qi 'self-signed' <<< "$output"; then
    echo -e "${YELLOW_BOLD}Self-signed${NC}"
  else
    echo -e "${RED}None${NC}"
  fi
}

extract_host() {
  local input="$1"
  input="${input#*://}"
  echo "${input%%[:/]*}"
}

# Perform a DNS lookup for a host and IP version within TIMEOUT.
# Sets DNS_IPS_FOUND to newline-separated matching addresses (may be empty).
dns_lookup() {
  local ip_version="$1" host="$2"
  local lookup ips ips_found
  DNS_IPS_FOUND=""

  # Try nslookup first
  if command -v timeout >/dev/null 2>&1; then
    lookup=$(timeout "$TIMEOUT" nslookup "$host" 2>/dev/null || true)
  else
    lookup=$(nslookup "$host" 2>/dev/null || true)
  fi
  ips=$(printf "%s" "$lookup" | awk '/^Address: /{print $2}' | uniq || true)

  # If no results, fallback to dig
  if [[ -z "$(printf "%s" "$ips" | tr -d '[:space:]')" ]] && command -v dig >/dev/null 2>&1; then
    if [[ "$ip_version" == "4" ]]; then
      if command -v timeout >/dev/null 2>&1; then
        lookup=$(timeout "$TIMEOUT" dig +short A "$host" 2>/dev/null || true)
      else
        lookup=$(dig +short A "$host" 2>/dev/null || true)
      fi
    elif [[ "$ip_version" == "6" ]]; then
      if command -v timeout >/dev/null 2>&1; then
        lookup=$(timeout "$TIMEOUT" dig +short AAAA "$host" 2>/dev/null || true)
      else
        lookup=$(dig +short AAAA "$host" 2>/dev/null || true)
      fi
    fi
    ips=$(printf "%s" "$lookup" | sed '/^\s*$/d' || true)
  fi

  if [[ -n "$ip_version" ]]; then
    if [[ "$ip_version" == "4" ]]; then
      ips_found=$(printf "%s\n" "$ips" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' || true)
    else
      ips_found=$(printf "%s\n" "$ips" | grep -E ':' || true)
    fi
  else
    ips_found="$ips"
  fi

  # Normalize to newline-separated list without empty lines
  DNS_IPS_FOUND=$(printf "%s\n" "$ips_found" | sed '/^\s*$/d' || true)
  if $DEBUG; then
    echo "[DEBUG] DNS lookup for $host (IPv${ip_version}): $DNS_IPS_FOUND"
  fi
}

# run curl for a given IP version and return values via globals
perform_curl() {
  local ip_version="$1" url="$2"
  # Only lookup the provided ip_version (fail fast if no record found within TIMEOUT)
  local host
  host=$(extract_host "$url")
  dns_lookup "$ip_version" "$host"
  if [[ -z "$(printf "%s" "$DNS_IPS_FOUND" | tr -d '[:space:]')" ]]; then
    # No DNS records found within timeout for requested IP version
    echo -e "${RED}${BOLD}DNS:${NC} No ${ip_version:+IPv${ip_version} }address for ${host} found within ${TIMEOUT}s" >&2
    CURL_OUTPUT=""
    CURL_HTTP_CODE="000"
    CURL_EFFECTIVE_URL=""
    return 1
  fi

  # Choose -4/-6 flag if ip_version present
  local flag=""
  if [[ -n "$ip_version" ]]; then
    flag="-$ip_version"
  fi

  # verbose (curl -v) output captured; final status line captured by -w
  output=$(curl --http3 -L $flag -s -o /dev/null -w "%{http_code} %{url_effective} %{remote_ip}" -v --connect-timeout "$TIMEOUT" "$url" 2>&1)
  if $DEBUG; then
    echo "[DEBUG] curl output: $output"
  fi
  read -r http_code url_effective remote_ip <<< "$(echo "$output" | tail -n1)"

  # If connection failed (000), retry with -k to ignore cert problems and capture
  if [[ "$http_code" = "000" ]]; then
    output=$(curl --http3 -k -L $flag -s -o /dev/null -w "%{http_code} %{url_effective} %{remote_ip}" -v --connect-timeout "$TIMEOUT" "$url" 2>&1)
    if $DEBUG; then
      echo "[DEBUG] curl retry output: $output"
    fi
    read -r http_code url_effective remote_ip <<< "$(echo "$output" | tail -n1)"
  fi

  # Exported globals
  CURL_OUTPUT="$output"
  CURL_HTTP_CODE="$http_code"
  CURL_EFFECTIVE_URL="$url_effective"
  CURL_REMOTE_IP="$remote_ip"
  return 0
}

check_and_print() {
  local ip_version="$1" url="$2" mode="$3"
  perform_curl "$ip_version" "$url"
  # If perform_curl returned non-zero, propagate failure to caller
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Try to extract resolved IP and TLS info
  tls_con=$(echo "$CURL_OUTPUT" | grep -oP 'SSL connection using \K.*' | head -1 || true)
  cert_status=$(get_cert_status "$CURL_OUTPUT")
  # Refactor cert_key_type extraction to remove trailing comma and improve readability
  cert_key_type=$(echo "$CURL_OUTPUT" | grep 'Certificate level' | tail -1 | sed -E 's/.*Public key type\s*([^,]+),?.*/\1/')
  cert_sign_algo=$(echo "$CURL_OUTPUT" | grep 'Certificate level' | tail -1 | sed -E 's/.*signed using\s*([^,]+).*/\1/')
  if echo "$CURL_OUTPUT" | grep -q 'using HTTP/3'; then
    http_version="3"
  else
    http_version=$(echo "$CURL_OUTPUT" | grep -oP 'using HTTP/\K[0-9.x]+' | head -1 || true)
  fi
  status_message=$(get_status_message "$CURL_HTTP_CODE")

  http_color=$(get_status_color "$CURL_HTTP_CODE")
  ip_color=$(./select_ip_color.sh "$ip_version")


  if [[ "$mode" = "short" ]]; then
    # Short single-line output similar to http-s_check_short.sh
    # Print: [STATUS] <code>  <url>  <resolved_ip padded> <CertStatus> Cert
    # Pad the IP column to align the certificate status column for IPv4/IPv6
    printf "[${http_color}${BOLD}%s${NC}] %s  %s  ${ip_color}%-39s${NC} %s Cert" \
      "$status_message" "$CURL_HTTP_CODE" "$url" "${CURL_REMOTE_IP:--}" "$cert_status"
  else
    printf "Resolved IPv%s:        ${ip_color}%s${NC}\n" "${ip_version}" "${CURL_REMOTE_IP:--}"
    printf "HTTP Version:         HTTP/%s\n" "${http_version:--}"
    if [[ -n "${tls_con}" ]]; then
      printf "TLS Connection:       %s\n" "${tls_con}"
    fi
    printf "Certificate:          %s\n" "${cert_status}"
    printf "Certificate Key Type: %s\n" "${cert_key_type}"
    printf "Cert Signature Algo:  %s\n" "${cert_sign_algo}"
    printf "URL:                  %s\n" "${url}"
    printf "Effective URL:        %s\n" "${CURL_EFFECTIVE_URL:--}"
    printf "Final HTTP Code:      %s [${http_color}${BOLD}%s${NC}]\n\n" "${CURL_HTTP_CODE}" "${status_message}"
  fi
}

if [[ -n "$IP_FORCED" ]]; then
  # force only 4 or only 6
  check_and_print "$IP_FORCED" "$URL" "$MODE"
else
  # run both; IPv4 then IPv6 (same order as originals)
  check_and_print 4 "$URL" "$MODE"
  echo ""
  check_and_print 6 "$URL" "$MODE"
fi

exit 0
