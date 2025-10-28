#!/bin/bash

CONFIG_FILE="./color.conf"
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=./color.conf
    source "$CONFIG_FILE"
else
    echo "$CONFIG_FILE file not found!" >&2
    exit 1
fi

user=$1
fqdn=$2
port=$3
ipv=$4

# Check required arguments
if [[ $# -lt 4 ]]; then
    echo -e "${RED}${BOLD}Usage:${NC} $0 <user> <fqdn> <port> <ip_version>"
    echo -e "  <user>        SSH username"
    echo -e "  <fqdn>        Fully Qualified Domain Name or IP"
    echo -e "  <port>        SSH port (e.g., 22)"
    echo -e "  <ip_version>  4 or 6"
    exit 1
fi

# # Choose the appropriate color based on IP version
# if [[ "$ipv" == "4" ]]; then
#     SelectedColor="$IPv4Color"
# elif [[ "$ipv" == "6" ]]; then
#     SelectedColor="$IPv6Color"
# else
#     SelectedColor="$NC" # Fallback/default
# fi
# Choose the appropriate color based on IP version
SelectedColor=$(./select_ip_color.sh "$ipv")

# SSH command using the selected color
ssh_output=$(ssh -n -T -q -F /dev/null -o BatchMode=yes -o ConnectTimeout=5 -p "$port" "$user@$fqdn" -"$ipv" \
    "echo -ne \"Connected from \$(echo \$SSH_CONNECTION | awk -v color='$SelectedColor' -v reset='$NC' -v text='$WHITE' '{print color \$1 \" \" text \$2 reset}') to \$(echo \$SSH_CONNECTION | awk -v color='$SelectedColor' -v reset='$NC' -v text='$WHITE' '{print color \$3 \" \" text \$4 reset}')\"")

ssh_status=$?

echo -e "ssh ${user}@${fqdn}${port:+:$port} -$ipv  "

if [[ $ssh_status -eq 0 ]]; then
    echo -e "$ssh_output"
    echo -e "SSH is ${GREEN}up ${NC}and accepting connections [${GREEN}${BOLD}OK${NC}${NORMAL}]"
else
    echo -e "SSH is ${RED}down ${NC}or not ready [${RED}${BOLD}Failed${NC}${NORMAL}]"
fi
