#!/bin/bash

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
Usage: $0 [OPTIONS] <user> <fqdn> <port> <ip_version>

Options:
  -s, --short        Short, one-line output
  -h, --help         Show this help

Arguments:
  <user>        SSH username
  <fqdn>        Fully Qualified Domain Name or IP
  <port>        SSH port (e.g., 22)
  <ip_version>  4 or 6

Examples:
  $0 -s user example.com 22 4
  $0 user example.com 22 6
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

if [[ $# -lt 4 ]]; then
  echo -e "${RED}${BOLD}Error:${NC} Missing required arguments."
  usage
  exit 1
fi

user=$1
fqdn=$2
port=$3
ipv=$4

# Choose the appropriate color based on IP version
if [[ "$ipv" == "4" ]]; then
  SelectedColor="$IPv4Color"
elif [[ "$ipv" == "6" ]]; then
  SelectedColor="$IPv6Color"
else
  SelectedColor="$NC" # Fallback/default
fi

# SSH command using the selected color
ssh_output=$(ssh -n -T -q -F /dev/null -o BatchMode=yes -o ConnectTimeout=5 -p "$port" "$user@$fqdn" -"$ipv" \
  "echo -ne \"Connected to \$(echo \$SSH_CONNECTION | awk -v color='$SelectedColor' -v reset='$NC' -v text='$WHITE' '{print color \$3 \" \" text \$4 reset}')\"")

ssh_status=$?

if [[ "$MODE" == "short" ]]; then
  if [[ $ssh_status -eq 0 ]]; then
    echo -ne "[${GREEN}${BOLD}OK${NC}] ssh ${user}@${fqdn}${port:+:$port} -$ipv is ${GREEN}up${NC} "
  else
    echo -ne "[${RED}${BOLD}FAILED${NC}] ssh ${user}@${fqdn}${port:+:$port} -$ipv is ${RED}down${NC} "
  fi
else
  echo -e "ssh ${user}@${fqdn}${port:+:$port} -$ipv"
  if [[ $ssh_status -eq 0 ]]; then
    echo -e "$ssh_output"
    echo -e "SSH is ${GREEN}up ${NC}and accepting connections [${GREEN}${BOLD}OK${NC}${NORMAL}]"
  else
    echo -e "SSH is ${RED}down ${NC}or not ready [${RED}${BOLD}Failed${NC}${NORMAL}]"
  fi
fi