# Windows Playwright Server for WSL Integration - Fixed Version
# This script runs on Windows and provides a WebSocket server for WSL to connect to

param(
    [int]$Port = 3333,
    [string]$Browser = "chromium"
)

Write-Host "Starting Playwright server on Windows (Fixed Version)..." -ForegroundColor Green
Write-Host "Port: $Port" -ForegroundColor Yellow
Write-Host "Browser: $Browser" -ForegroundColor Yellow

# Check if Node.js is installed
try {
    $nodeVersion = node --version
    Write-Host "Node.js version: $nodeVersion" -ForegroundColor Cyan
} catch {
    Write-Host "Node.js is not installed. Please install Node.js first." -ForegroundColor Red
    exit 1
}

# Create a temporary directory for the server
$tempDir = Join-Path $env:TEMP "playwright-wsl-server"
if (!(Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
}

Set-Location $tempDir

# Create a server script that properly handles the connection
$serverScript = @'
const { chromium, firefox, webkit } = require('playwright');
const WebSocket = require('ws');

const PORT = process.argv[2] || 3333;
const BROWSER_TYPE = process.argv[3] || 'chromium';

console.log(`Starting custom Playwright WebSocket server on port ${PORT}...`);

const wss = new WebSocket.Server({ port: PORT });

wss.on('connection', async (ws) => {
    console.log('New WebSocket connection received');
    
    let browser;
    let context;
    
    try {
        // Launch the browser based on type
        console.log(`Launching ${BROWSER_TYPE} browser...`);
        switch(BROWSER_TYPE) {
            case 'firefox':
                browser = await firefox.launch({ headless: false });
                break;
            case 'webkit':
                browser = await webkit.launch({ headless: false });
                break;
            default:
                browser = await chromium.launch({ headless: false });
        }
        
        console.log('Browser launched successfully');
        
        // Handle incoming messages
        ws.on('message', async (data) => {
            try {
                const message = JSON.parse(data.toString());
                console.log('Received message:', message.method || message);
                
                // Simple command handling
                if (message.method === 'Browser.newPage') {
                    const page = await browser.newPage();
                    ws.send(JSON.stringify({ id: message.id, result: { pageId: page._guid } }));
                } else if (message.method === 'Page.goto') {
                    // This is a simplified example
                    ws.send(JSON.stringify({ id: message.id, result: {} }));
                }
            } catch (e) {
                console.error('Error handling message:', e);
            }
        });
        
        ws.on('close', () => {
            console.log('WebSocket connection closed');
            if (browser) browser.close();
        });
        
    } catch (error) {
        console.error('Error:', error);
        ws.close();
    }
});

console.log(`WebSocket server listening on ws://localhost:${PORT}/`);
console.log('Press Ctrl+C to stop the server');
'@

# Save the server script
$serverScript | Out-File -FilePath "custom-server.js" -Encoding utf8

# Create package.json if it doesn't exist
if (!(Test-Path "package.json")) {
    $packageJson = @{
        name = "playwright-wsl-server"
        version = "1.0.0"
        description = "Playwright server for WSL integration"
        dependencies = @{
            playwright = "latest"
            ws = "latest"
        }
    }
    $packageJson | ConvertTo-Json | Out-File -FilePath "package.json" -Encoding utf8
}

# Install dependencies if needed
if (!(Test-Path "node_modules\playwright")) {
    Write-Host "Installing Playwright..." -ForegroundColor Yellow
    npm install
}

if (!(Test-Path "node_modules\ws")) {
    Write-Host "Installing WebSocket library..." -ForegroundColor Yellow
    npm install ws
}

# Install browser if needed
Write-Host "Installing $Browser browser..." -ForegroundColor Yellow
npx playwright install $Browser

# Get the local IP addresses
Write-Host "`nAvailable endpoints:" -ForegroundColor Cyan
Write-Host "  ws://localhost:$Port/" -ForegroundColor Green
Write-Host "  ws://127.0.0.1:$Port/" -ForegroundColor Green

# Get the machine name
$hostname = hostname
Write-Host "  ws://${hostname}:$Port/" -ForegroundColor Green

# Try to get the WSL-accessible IP
$wslIP = Get-NetIPAddress | Where-Object {$_.InterfaceAlias -like "*WSL*" -and $_.AddressFamily -eq "IPv4"} | Select-Object -First 1 -ExpandProperty IPAddress
if ($wslIP) {
    Write-Host "  ws://${wslIP}:$Port/ (WSL interface)" -ForegroundColor Yellow
}

Write-Host "`nNOTE: This is using the standard 'npx playwright run-server' command" -ForegroundColor Cyan
Write-Host "If connection fails, try the alternative custom server approach" -ForegroundColor Cyan
Write-Host "`nPress Ctrl+C to stop the server" -ForegroundColor Yellow

# Start the standard Playwright server
# The Elixir library should be able to connect to this
npx playwright run-server --port $Port