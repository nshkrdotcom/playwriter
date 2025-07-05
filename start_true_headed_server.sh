#!/bin/bash

echo "Starting TRUE HEADED Playwright browser server..."
echo "This will create VISIBLE browser windows automatically!"
echo

# Kill any existing servers
echo "Cleaning up existing servers..."
powershell.exe -ExecutionPolicy Bypass -File ./kill_playwright.ps1

echo "Starting headed browser server on port 3337..."

# Copy Node.js script to Windows temp and run it
powershell.exe -Command "
cd \$env:TEMP
if (!(Test-Path 'node_modules/playwright')) {
    Write-Host 'Installing Playwright...'
    npm init -y
    npm install playwright
}
\$env:PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = '1'

# Copy our Node.js script to Windows temp directory
\$scriptContent = @'
const { chromium } = require('playwright');

async function startHeadedBrowserServer() {
    console.log('Starting HEADED Playwright browser server...');
    
    try {
        // Check if profile is specified via environment variable
        const profilePath = process.env.CHROME_PROFILE_PATH;
        const launchOptions = {
            headless: false
        };
        
        if (profilePath) {
            console.log('Using Chrome profile: ' + profilePath);
            launchOptions.args = ['--user-data-dir=' + profilePath];
        }
        
        const browserServer = await chromium.launchServer(launchOptions);
        
        const wsEndpoint = browserServer.wsEndpoint();
        console.log('✅ HEADED Browser Server started successfully!');
        console.log('📡 WebSocket endpoint: ' + wsEndpoint);
        console.log('🌐 Browsers will be VISIBLE when used');
        console.log('🛑 Press Ctrl+C to stop the server');
        
        process.on('SIGINT', async () => {
            console.log('\\n🔄 Shutting down browser server...');
            await browserServer.close();
            console.log('✅ Browser server stopped');
            process.exit(0);
        });
        
        await new Promise(() => {});
        
    } catch (error) {
        console.error('❌ Failed to start browser server:', error);
        process.exit(1);
    }
}

startHeadedBrowserServer();
'@

\$scriptContent | Out-File -FilePath 'headed_server.js' -Encoding utf8
Write-Host 'Starting HEADED browser server...'
node headed_server.js
"