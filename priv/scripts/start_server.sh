#!/bin/bash
# Start Windows Playwright server from WSL
# This runs PowerShell on Windows to start the server

PORT=${1:-3337}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting Windows Playwright server on port $PORT..."
echo "This will open PowerShell on Windows."
echo ""

# Check if powershell.exe is available (indicates WSL)
if command -v powershell.exe &> /dev/null; then
    # Convert WSL path to Windows path
    WIN_SCRIPT=$(wslpath -w "$SCRIPT_DIR/start_server.ps1")

    echo "Running: powershell.exe -ExecutionPolicy Bypass -File $WIN_SCRIPT -Port $PORT"
    echo ""

    powershell.exe -ExecutionPolicy Bypass -File "$WIN_SCRIPT" -Port $PORT
else
    echo "Error: powershell.exe not found."
    echo "This script is designed to run from WSL to start a Windows Playwright server."
    echo ""
    echo "If you're on native Linux/macOS, use local mode instead:"
    echo "  Playwriter.fetch_html(url, headless: true)"
    exit 1
fi
