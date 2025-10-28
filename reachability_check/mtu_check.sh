#!/bin/bash

# Default values
step=1
ip_version=6

# Parse options before the hostname/IP address
while [[ "$1" =~ ^- ]]; do
    case "$1" in
        -s|--step)
            step="$2"
            shift 2
            ;;
        --step=*)
            step="${1#*=}"
            shift
            ;;
        -4)
            ip_version=4
            shift
            ;;
        -6)
            ip_version=6
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Capture the hostname/IP address
hostname="$1"
shift

# Resume option parsing after the hostname/IP address
while [[ "$1" =~ ^- ]]; do
    case "$1" in
        -s|--step)
            step="$2"
            shift 2
            ;;
        --step=*)
            step="${1#*=}"
            shift
            ;;
        -4)
            ip_version=4
            shift
            ;;
        -6)
            ip_version=6
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate hostname/IP
if [ -z "$hostname" ]; then
    echo "Usage: $0 [options] <hostname_or_ip> [options]"
    exit 1
fi

# Validate step value
if ! [[ "$step" =~ ^[0-9]+$ ]] || [ "$step" -le 0 ]; then
    echo "Invalid step value. Using default step of 1."
    step=1
fi

# Main logic
for ((i=1500; i>=1000; i-=step)); do
    if [ "$ip_version" -eq 6 ]; then
        size=$(($i - 48))
    else
        size=$(($i - 28))
    fi

    if ping -$ip_version -c 1 -W 1 -s $size -M probe "$hostname" > /dev/null 2>&1; then
        echo -e "\nMTU: $i"
        break
    else echo -ne "."
    fi
done