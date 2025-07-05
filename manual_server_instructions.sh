#!/bin/bash

echo "=============================================="
echo "Playwright Windows Browser Server Instructions"
echo "=============================================="
echo
echo "To use Windows browsers from WSL, you need to manually start"
echo "the Playwright server on Windows. Here's how:"
echo
echo "1. Open PowerShell on Windows (as your regular user)"
echo
echo "2. Run these commands:"
echo "   cd \$env:TEMP"
echo "   npx -y playwright install chromium"
echo "   npx -y playwright install firefox"  
echo "   npx playwright run-server --port 3333"
echo
echo "3. You should see output like:"
echo "   'Listening on ws://localhost:3333/'"
echo
echo "4. Leave that PowerShell window open while using the browser"
echo
echo "5. Then from WSL, run:"
echo "   ./playwriter --windows-browser https://example.com"
echo
echo "=============================================="
echo
echo "Checking current server status..."

# Check if server is running
WINDOWS_HOST=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}')

if timeout 2 bash -c "echo >/dev/tcp/localhost/3333" 2>/dev/null; then
    echo "✓ Playwright server is running and accessible via localhost:3333"
elif timeout 2 bash -c "echo >/dev/tcp/$WINDOWS_HOST/3333" 2>/dev/null; then
    echo "✓ Playwright server is running and accessible via $WINDOWS_HOST:3333"
else
    echo "❌ No Playwright server detected"
    echo
    echo "Please run the commands above in PowerShell on Windows,"
    echo "then try your Elixir command again."
fi