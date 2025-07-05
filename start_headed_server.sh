#!/bin/bash

echo "Starting HEADED Playwright server on Windows..."
echo "This will open VISIBLE browser windows!"
echo

# Simple PowerShell command to start headed server
powershell.exe -Command "
    Write-Host 'Starting HEADED Playwright server on port 3334...'
    cd \$env:TEMP
    if (!(Test-Path 'package.json')) {
        npm init -y
        npm install playwright
    }
    npx playwright install chromium --force
    Write-Host 'Starting server with VISIBLE browsers...'
    npx playwright run-server --port 3335
"

echo "Server should now be running on port 3334"