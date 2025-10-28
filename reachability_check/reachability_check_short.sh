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
        ./dns_check_short.sh "$fqdn" ${dns_ip:+$dns_ip}
        ;;
    https)
        ./http-s_check_short.sh $protocol://$fqdn${port:+:$port}
        ;;
    http)
        ./http-s_check_short.sh $protocol://$fqdn${port:+:$port}
        ;;
    mqtt)
        #echo $entry # debug logging
        ./mqtt-s_check_short.sh "$entry"
        ;;
    ssh)
        if [[ -z "$ipv" ]]; then
            ./ssh_check_short.sh "${user}" "${fqdn}" "${port:+$port}" "4"
            echo ""
            ./ssh_check_short.sh "${user}" "${fqdn}" "${port:+$port}" "6"
        elif [[ "$ipv" == "4" ]]; then
            ./ssh_check_short.sh "${user}" "${fqdn}" "${port:+$port}" "4"
        elif [[ "$ipv" == "6" ]]; then
            ./ssh_check_short.sh "${user}" "${fqdn}" "${port:+$port}" "6"
        else
            echo -e "-> Unknown IPv version: $ipv"
        fi
        ;;
    *)
        echo -e "-> Unknown protocol: $protocol"
        ;;
    esac

    echo ""
done
