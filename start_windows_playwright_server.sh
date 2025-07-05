#!/bin/bash

# Simple reliable script to start Playwright server on Windows
echo "Starting Playwright server on Windows..."

# Get Windows host IP for connection testing
WINDOWS_HOST=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}')
echo "Windows host IP: $WINDOWS_HOST"

# Check if server is already running
echo "Checking if server is already running..."
if timeout 2 bash -c "echo >/dev/tcp/$WINDOWS_HOST/3333" 2>/dev/null; then
    echo "✓ Playwright server is already running at $WINDOWS_HOST:3333"
    exit 0
fi

if timeout 2 bash -c "echo >/dev/tcp/localhost/3333" 2>/dev/null; then
    echo "✓ Playwright server is already running at localhost:3333"
    exit 0
fi

echo "No server found, starting new one..."

# Simple PowerShell command to start the server
powershell.exe -Command "
    Write-Host 'Starting Playwright server from WSL...'
    cd \$env:TEMP
    if (!(Test-Path 'package.json')) {
        npm init -y
        npm install playwright
    }
    Write-Host 'Installing browsers...'
    npx playwright install chromium --force
    Write-Host 'Starting server on port 3333...'
    Start-Process powershell -ArgumentList '-NoExit', '-Command', 'cd \$env:TEMP; npx playwright run-server --port 3333'
    Write-Host 'Server starting in new window...'
"

echo "Server startup initiated. Waiting for it to be ready..."

# Wait up to 30 seconds for server to start
for i in {1..30}; do
    echo -n "Checking connection (attempt $i/30)... "
    
    if timeout 2 bash -c "echo >/dev/tcp/$WINDOWS_HOST/3333" 2>/dev/null; then
        echo "✓ Connected to $WINDOWS_HOST:3333"
        echo "Playwright server is ready!"
        exit 0
    elif timeout 2 bash -c "echo >/dev/tcp/localhost/3333" 2>/dev/null; then
        echo "✓ Connected to localhost:3333"
        echo "Playwright server is ready!"
        exit 0
    else
        echo "Not ready yet..."
        sleep 1
    fi
done

echo "❌ Server failed to start or is not accessible"
echo "You may need to:"
echo "1. Install Node.js on Windows"
echo "2. Allow Node.js through Windows Firewall"
echo "3. Manually run: powershell.exe -Command 'cd \$env:TEMP; npx playwright run-server --port 3333'"
exit 1