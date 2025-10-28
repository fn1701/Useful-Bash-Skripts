#!/bin/bash

# Colors for output
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
Usage: $0 [OPTIONS] <json_file>

Options:
  -s, --short        Short, one-line output
  -v, --verbose      Verbose multi-line output (default)
  -h, --help         Show this help

Examples:
  $0 -s input.json
  $0 -v input.json
EOF
}

# Default mode
mode="verbose"

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--short) mode="short"; shift ;;
    -v|--verbose) mode="verbose"; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) echo -e "${RED}Unknown option: $1${NC}"; usage; exit 2 ;;
    *) break ;;
  esac
done

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

# Path to your JSON file
json_file="$1"

# Loop through each item in the JSON array
jq -c '.[]' "$json_file" | while IFS= read -r entry; do
    protocol=$(jq -r '.protocol' <<<"$entry" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    fqdn=$(jq -r '.fqdn' <<<"$entry")
    port=$(jq -r '.port // empty' <<<"$entry")     # optional
    user=$(jq -r '.user // empty' <<<"$entry")     # optional
    dns_ip=$(jq -r '.dns_ip // empty' <<<"$entry") # optional
    ipv=$(jq -r '.ipv // empty' <<<"$entry")       # optional

    case "$protocol" in
    dns)
        if [[ "$mode" == "short" ]]; then
            ./dns_check_short.sh "$fqdn" ${dns_ip:+$dns_ip}
        else
            ./dns_check.sh "$fqdn" ${dns_ip:+$dns_ip}
        fi
        ;;
    https|http)
        if [[ "$mode" == "short" ]]; then
            ./http-s_check.sh -s $protocol://$fqdn${port:+:$port}
        else
            ./http-s_check.sh $protocol://$fqdn${port:+:$port}
        fi
        ;;
    mqtt)
        if [[ "$mode" == "short" ]]; then
            ./mqtt-s_check_short.sh "$entry"
        else
            ./mqtt-s_check.sh "$entry"
        fi
        ;;
    ssh)
        if [[ -z "$ipv" ]]; then
            if [[ "$mode" == "short" ]]; then
                ./ssh_check_short.sh "${user}" "${fqdn}" "${port:+$port}" "4"
                echo ""
                ./ssh_check_short.sh "${user}" "${fqdn}" "${port:+$port}" "6"
            else
                ./ssh_check.sh "${user}" "${fqdn}" "${port:+$port}" "4"
                echo ""
                ./ssh_check.sh "${user}" "${fqdn}" "${port:+$port}" "6"
            fi
        elif [[ "$ipv" == "4" ]]; then
            if [[ "$mode" == "short" ]]; then
                ./ssh_check_short.sh "${user}" "${fqdn}" "${port:+$port}" "4"
            else
                ./ssh_check.sh "${user}" "${fqdn}" "${port:+$port}" "4"
            fi
        elif [[ "$ipv" == "6" ]]; then
            if [[ "$mode" == "short" ]]; then
                ./ssh_check_short.sh "${user}" "${fqdn}" "${port:+$port}" "6"
            else
                ./ssh_check.sh "${user}" "${fqdn}" "${port:+$port}" "6"
            fi
        else
            echo -e "${RED}-> Unknown IPv version: $ipv${NC}"
        fi
        ;;
    *)
        echo -e "${RED}-> Unknown protocol: $protocol${NC}"
        ;;
    esac

    echo ""
done