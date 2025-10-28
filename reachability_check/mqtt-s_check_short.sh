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

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo -e "${RED}Usage: $0 '<json-string>'${NC}"
  exit 1
fi

json="$1"

# Extract mandatory fields
fqdn=$(jq -r '.fqdn' <<<"$json")
user=$(jq -r '.mqtt_options["-u"] // empty' <<<"$json")
port=$(jq -r '.mqtt_options["-p"] // 1883' <<<"$json")

# Parse mqtt_options object (or empty)
mqtt_options_json=$(jq -c '.mqtt_options // {}' <<<"$json")

mqtt_opts=()
for key in $(jq -r 'keys[]' <<<"$mqtt_options_json"); do
  val=$(jq -r --arg k "$key" '.[$k]' <<<"$mqtt_options_json")
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
  echo -ne "[${GREEN}${BOLD}OK${NC}${NORMAL}] "
  echo -ne "$prefix"
  echo -ne "$user"@"$fqdn":"$port "
  echo -ne "${GREEN}Broker reachable and responding.${NC}"
  exit 0
else
  echo -ne "[${RED}${BOLD}Failed${NC}${NORMAL}] "
  echo -ne "$prefix"
  echo -ne "$user"@"$fqdn":"$port "
  echo -ne "${RED}Broker not reachable or no response.${NC}"
  exit 3
fi
