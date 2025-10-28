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
Usage: $0 [OPTIONS] '<json-string>'

Options:
  -s, --short        Short, one-line output
  -h, --help         Show this help

Arguments:
  <json-string>  JSON string containing MQTT connection details

Examples:
  $0 -s '{"fqdn": "example.com", "mqtt_options": {"-u": "user", "-p": "1883"}}'
  $0 '{"fqdn": "example.com", "mqtt_options": {"-u": "user", "-p": "1883"}}'
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

if [[ $# -ne 1 ]]; then
  echo -e "${RED}${BOLD}Error:${NC} Missing required argument."
  usage
  exit 1
fi

json="$1"

# Extract mandatory fields
fqdn=$(jq -r '.fqdn' <<< "$json")
user=$(jq -r '.mqtt_options["-u"] // empty' <<< "$json")
port=$(jq -r '.mqtt_options["-p"] // 1883' <<< "$json")

# Parse mqtt_options object (or empty)
mqtt_options_json=$(jq -c '.mqtt_options // {}' <<< "$json")

mqtt_opts=()
for key in $(jq -r 'keys[]' <<< "$mqtt_options_json"); do
  val=$(jq -r --arg k "$key" '.[$k]' <<< "$mqtt_options_json")
  if [[ "$val" == "false" ]]; then
    mqtt_opts+=("$key")
  else
    mqtt_opts+=("$key" "$val")
  fi
done

prefix=""
if openssl s_client -connect "$fqdn:$port" -brief </dev/null 2>&1 | grep -qi "protocol"; then
  prefix="mqtts://"
else
  prefix="mqtt://"
fi

if mosquitto_sub "-h" "$fqdn" "${mqtt_opts[@]}" -C 1 -W 5 >/dev/null 2>&1; then
  if [[ "$MODE" == "short" ]]; then
    echo -ne "[${GREEN}${BOLD}OK${NC}${NORMAL}] $prefix$user@$fqdn:$port ${GREEN}Broker reachable and responding.${NC}"
  else
    echo -e "$user@$fqdn:$port"
    echo -e "${GREEN}MQTT broker reachable and responding.${NC} [${GREEN}${BOLD}OK${NC}${NORMAL}]"
  fi
  exit 0
else
  if [[ "$MODE" == "short" ]]; then
    echo -ne "[${RED}${BOLD}Failed${NC}${NORMAL}] $prefix$user@$fqdn:$port ${RED}Broker not reachable or no response.${NC}"
  else
    echo -e "$user@$fqdn:$port"
    echo -e "${RED}MQTT broker not reachable or no response.${NC} [${RED}${BOLD}Failed${NC}${NORMAL}]"
  fi
  exit 3
fi