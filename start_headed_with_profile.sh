#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <profile_name>"
    echo "Example: $0 Default"
    echo "Example: $0 'Profile 1'"
    echo ""
    echo "Use --list-profiles to see available profiles"
    exit 1
fi

PROFILE_NAME="$1"

echo "Starting HEADED Playwright server with Chrome profile: $PROFILE_NAME"
echo "This will use your existing Chrome data, cookies, and extensions!"
echo

# Kill any existing servers
echo "Cleaning up existing servers..."
powershell.exe -ExecutionPolicy Bypass -File ./kill_playwright.ps1

echo "Starting headed browser server with profile '$PROFILE_NAME'..."

# Get the profile path
PROFILE_PATH=$(powershell.exe -Command "\$env:LOCALAPPDATA + '\\Google\\Chrome\\User Data\\$PROFILE_NAME'")
PROFILE_PATH=$(echo "$PROFILE_PATH" | tr -d '\r')

echo "Profile path: $PROFILE_PATH"

# Start server with profile
powershell.exe -Command "
cd \$env:TEMP
if (!(Test-Path 'node_modules/playwright')) {
    Write-Host 'Installing Playwright...'
    npm init -y
    npm install playwright
}
\$env:PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = '1'
\$env:CHROME_PROFILE_PATH = '$PROFILE_PATH'

\$scriptContent = @'
const { chromium } = require('playwright');

async function startHeadedBrowserServer() {
    console.log('Starting HEADED Playwright browser server with profile...');
    
    try {
        const profilePath = process.env.CHROME_PROFILE_PATH;
        const launchOptions = {
            headless: false
        };
        
        if (profilePath) {
            console.log('Using Chrome profile: ' + profilePath);
            launchOptions.args = ['--user-data-dir=' + profilePath];
        }
        
        // For profiles, use launchPersistentContext instead of launchServer
        const context = await chromium.launchPersistentContext(profilePath, {
            headless: false
        });
        
        console.log('✅ HEADED Browser Context started successfully!');
        console.log('👤 Using Chrome profile: ' + profilePath);
        console.log('🌐 Browser is using your existing data and extensions');
        console.log('📝 Note: This runs a persistent context, not a server');
        console.log('🛑 Press Ctrl+C to stop');
        
        process.on('SIGINT', async () => {
            console.log('\\n🔄 Shutting down browser context...');
            await context.close();
            console.log('✅ Browser context stopped');
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

\$scriptContent | Out-File -FilePath 'headed_server_with_profile.js' -Encoding utf8
Write-Host 'Starting HEADED browser server with profile...'
node headed_server_with_profile.js
"