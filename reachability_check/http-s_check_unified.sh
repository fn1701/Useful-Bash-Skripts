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

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--short) MODE=short; shift ;;
    -v|--verbose) MODE=verbose; shift ;;
    -4) IP_FORCED=4; shift ;;
    -6) IP_FORCED=6; shift ;;
  -t) TIMEOUT="$2"; shift 2 ;;
  --timeout) TIMEOUT="$2"; shift 2 ;;
  --timeout=*) TIMEOUT="${1#*=}"; shift ;;
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

# run curl for a given IP version and return values via globals
perform_curl() {
  local ip_version="$1" url="$2"
  # Choose -4/-6 flag if ip_version present
  local flag=""
  if [[ -n "$ip_version" ]]; then
    flag="-$ip_version"
  fi

  # verbose (curl -v) output captured; final status line captured by -w
  output=$(curl -L $flag -s -o /dev/null -w "%{http_code} %{url_effective}" -v --connect-timeout "$TIMEOUT" "$url" 2>&1)
  read -r http_code url_effective <<< "$(echo "$output" | tail -n1)"

  # If connection failed (000), retry with -k to ignore cert problems and capture
  if [[ "$http_code" = "000" ]]; then
  output=$(curl -k -L $flag -s -o /dev/null -w "%{http_code} %{url_effective}" -v --connect-timeout "$TIMEOUT" "$url" 2>&1)
    read -r http_code url_effective <<< "$(echo "$output" | tail -n1)"
  fi

  # Exported globals
  CURL_OUTPUT="$output"
  CURL_HTTP_CODE="$http_code"
  CURL_EFFECTIVE_URL="$url_effective"
}

check_and_print() {
  local ip_version="$1" url="$2" mode="$3"
  perform_curl "$ip_version" "$url"

  # Try to extract resolved IP and TLS info
  resolved_ip=$(echo "$CURL_OUTPUT" | grep -oP "IPv${ip_version}:\s+\K([0-9a-fA-F:.]{7,39})" | head -1 || true)
  tls_info=$(echo "$CURL_OUTPUT" | grep -oP 'SSL connection using \K.*' | head -1 || true)
  cert_status=$(get_cert_status "$CURL_OUTPUT")

  status_message=$(get_status_message "$CURL_HTTP_CODE")
  color=$(get_status_color "$CURL_HTTP_CODE")

  if [[ "$mode" = "short" ]]; then
    # Short single-line output similar to http-s_check_short.sh
    # Print: [STATUS] <code>  <url>  <resolved_ip>  <CertStatus> Cert
    printf "[${color}${BOLD}%s${NC}] %s  %s  %s  %s Cert\n" \
      "$status_message" "$CURL_HTTP_CODE" "$url" "${resolved_ip:--}" "$cert_status"
  else
    # Verbose multi-line output similar to http-s_check.sh
    echo -e "Resolved IPv${ip_version}:      ${resolved_ip:--}"
    echo -e "TLS Info:           ${tls_info:--}"
    echo -e "Certificate:        ${cert_status}"
    echo -e "Effective URL:      ${CURL_EFFECTIVE_URL:--}"
    echo -e "Final HTTP Code:    ${CURL_HTTP_CODE} [${color}${BOLD}${status_message}${NC}]\n"
  fi
}

# Verify host DNS first to avoid some curl IPv6 lookup delays
host=$(extract_host "$URL")
if command -v timeout >/dev/null 2>&1; then
  timeout "$TIMEOUT" nslookup "$host" &>/dev/null || true
else
  nslookup "$host" &>/dev/null || true
fi

if [[ -n "$IP_FORCED" ]]; then
  # force only 4 or only 6
  check_and_print "$IP_FORCED" "$URL" "$MODE"
else
  # run both; IPv4 then IPv6 (same order as originals)
  check_and_print 4 "$URL" "$MODE"
  if [[ "$MODE" = "short" ]]; then
    # short prints one-line; print newline then run IPv6 short line
    :
  fi
  check_and_print 6 "$URL" "$MODE"
fi

exit 0
