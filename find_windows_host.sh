#!/bin/bash

echo "Finding Windows host IP address..."
echo

# Method 1: Check /etc/resolv.conf
echo "Method 1 - /etc/resolv.conf:"
NAMESERVER=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}')
echo "  Nameserver: $NAMESERVER"

# Method 2: Check default gateway
echo
echo "Method 2 - Default gateway:"
GATEWAY=$(ip route | grep default | awk '{print $3}')
echo "  Gateway: $GATEWAY"

# Method 3: Check for WSL2 specific host
echo
echo "Method 3 - WSL2 host.docker.internal:"
if getent hosts host.docker.internal >/dev/null 2>&1; then
    HOST_DOCKER=$(getent hosts host.docker.internal | awk '{print $1}')
    echo "  host.docker.internal: $HOST_DOCKER"
else
    echo "  host.docker.internal: Not available"
fi

# Method 4: Try to ping the Windows host
echo
echo "Method 4 - Windows host via PowerShell:"
WINDOWS_IP=$(powershell.exe -Command "(Get-NetIPAddress -InterfaceAlias 'vEthernet (WSL)' -AddressFamily IPv4).IPAddress" 2>/dev/null | tr -d '\r\n')
if [ -n "$WINDOWS_IP" ]; then
    echo "  Windows WSL adapter: $WINDOWS_IP"
else
    echo "  Windows WSL adapter: Not found"
fi

# Method 5: Try localhost
echo
echo "Method 5 - Localhost forwarding:"
echo "  localhost (127.0.0.1) - Often works if Windows firewall allows it"

echo
echo "Testing connectivity to port 3333..."
echo

# Test each potential host
for host in "$NAMESERVER" "$GATEWAY" "$HOST_DOCKER" "$WINDOWS_IP" "127.0.0.1" "localhost"; do
    if [ -n "$host" ] && [ "$host" != "" ]; then
        echo -n "Testing $host:3333... "
        if timeout 1 bash -c "echo >/dev/tcp/$host/3333" 2>/dev/null; then
            echo "✓ SUCCESS!"
            echo
            echo "Working endpoint: ws://$host:3333/"
            echo
            echo "To use this endpoint:"
            echo "  export PLAYWRIGHT_WS_ENDPOINT=ws://$host:3333/"
            echo "  ./playwriter --windows-browser https://example.com"
            break
        else
            echo "✗ Failed"
        fi
    fi
done